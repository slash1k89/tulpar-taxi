import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'tulpar_api_client.dart';

class DriverTrackingService {
  static const Duration serverWriteInterval = Duration(seconds: 3);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TulparApiClient _apiClient = TulparApiClient();

  StreamSubscription<Position>? _positionStreamSubscription;

  LatestValueWriteThrottler<Position>? _serverWriter;

  final ValueNotifier<LatLng?> _positionNotifier = ValueNotifier<LatLng?>(null);

  bool _isDisposed = false;
  int _trackingSession = 0;

  ValueListenable<LatLng?> get positionListenable => _positionNotifier;

  LatLng? get latestPosition => _positionNotifier.value;

  Future<DriverTrackingResult> startLocationUpdates(String orderId) async {
    if (_isDisposed) {
      return const DriverTrackingResult.failure(
        'тслеживание геопозиции уже остановлено.',
      );
    }

    final session = ++_trackingSession;

    final user = _auth.currentUser;

    if (user == null) {
      return const DriverTrackingResult.failure('ойдите в аккаунт водителя.');
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!_isSessionActive(session)) {
      return const DriverTrackingResult.failure(
        'тслеживание геопозиции остановлено.',
      );
    }

    if (!serviceEnabled) {
      return const DriverTrackingResult.failure('ключите службы геолокации.');
    }

    var permission = await Geolocator.checkPermission();

    if (!_isSessionActive(session)) {
      return const DriverTrackingResult.failure(
        'тслеживание геопозиции остановлено.',
      );
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (!_isSessionActive(session)) {
        return const DriverTrackingResult.failure(
          'тслеживание геопозиции остановлено.',
        );
      }

      if (permission == LocationPermission.denied) {
        return const DriverTrackingResult.failure(
          'азрешите доступ к геолокации.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const DriverTrackingResult.failure(
        'оступ к геолокации отключён в настройках.',
      );
    }

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    await _serverWriter?.close();
    _serverWriter = null;

    if (!_isSessionActive(session)) {
      return const DriverTrackingResult.failure(
        'тслеживание геопозиции остановлено.',
      );
    }

    _serverWriter = LatestValueWriteThrottler<Position>(
      minimumInterval: serverWriteInterval,
      write: (position) => _apiClient.updateDriverLocation(
        orderId: orderId,
        lat: position.latitude,
        lng: position.longitude,
      ),
    );

    try {
      final position = await Geolocator.getCurrentPosition();

      if (!_isSessionActive(session)) {
        return const DriverTrackingResult.failure(
          'тслеживание геопозиции остановлено.',
        );
      }

      _publishPosition(position);

      await _serverWriter!.writeImmediately(position);
    } catch (error) {
      debugPrint('[DriverTracking] initial position failed: $error');

      return const DriverTrackingResult.failure(
        'е удалось получить или отправить текущую геопозицию.',
      );
    }

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (position) {
            if (!_isSessionActive(session)) {
              return;
            }

            _publishPosition(position);
            _serverWriter?.add(position);
          },
          onError: (Object error) {
            debugPrint('[DriverTracking] position stream error: $error');
          },
        );

    return const DriverTrackingResult.started();
  }

  void _publishPosition(Position position) {
    if (_isDisposed) {
      return;
    }

    _positionNotifier.value = LatLng(position.latitude, position.longitude);
  }

  bool _isSessionActive(int session) {
    return !_isDisposed && session == _trackingSession;
  }

  Future<void> stopLocationUpdates(String orderId) async {
    _trackingSession++;

    await _positionStreamSubscription?.cancel();

    _positionStreamSubscription = null;

    await _serverWriter?.close();
    _serverWriter = null;
  }

  Future<void> dispose(String orderId) async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;

    await stopLocationUpdates(orderId);
    _positionNotifier.dispose();
  }
}

class LatestValueWriteThrottler<T> {
  LatestValueWriteThrottler({
    required this.minimumInterval,
    required Future<void> Function(T value) write,
  }) : _write = write;

  final Duration minimumInterval;
  final Future<void> Function(T value) _write;

  T? _pendingValue;
  bool _hasPendingValue = false;
  bool _isWriteInProgress = false;
  bool _isClosed = false;

  DateTime? _lastWriteStartedAt;
  Timer? _timer;
  Future<void>? _activeWrite;

  void add(T value) {
    if (_isClosed) {
      return;
    }

    _pendingValue = value;
    _hasPendingValue = true;
    _scheduleWrite();
  }

  Future<void> writeImmediately(T value) async {
    if (_isClosed) {
      return;
    }

    _pendingValue = value;
    _hasPendingValue = true;

    _timer?.cancel();
    _timer = null;

    if (_isWriteInProgress) {
      return;
    }

    await _flush();
  }

  void _scheduleWrite() {
    if (_isClosed ||
        _isWriteInProgress ||
        !_hasPendingValue ||
        _timer != null) {
      return;
    }

    final lastWriteStartedAt = _lastWriteStartedAt;

    if (lastWriteStartedAt == null) {
      _startFlush();
      return;
    }

    final elapsed = DateTime.now().difference(lastWriteStartedAt);

    final remaining = minimumInterval - elapsed;

    if (remaining <= Duration.zero) {
      _startFlush();
      return;
    }

    _timer = Timer(remaining, () {
      _timer = null;
      _startFlush();
    });
  }

  void _startFlush() {
    unawaited(
      _flush().catchError((Object error) {
        debugPrint('[DriverTracking] server write failed: $error');
      }),
    );
  }

  Future<void> _flush() async {
    if (_isClosed || _isWriteInProgress || !_hasPendingValue) {
      return;
    }

    _timer?.cancel();
    _timer = null;

    final value = _pendingValue as T;

    _pendingValue = null;
    _hasPendingValue = false;

    _isWriteInProgress = true;
    _lastWriteStartedAt = DateTime.now();

    final activeWrite = Future<void>.sync(() => _write(value));

    _activeWrite = activeWrite;

    try {
      await activeWrite;
    } finally {
      _activeWrite = null;
      _isWriteInProgress = false;

      if (!_isClosed) {
        _scheduleWrite();
      }
    }
  }

  Future<void> close() async {
    if (_isClosed) {
      return;
    }

    _isClosed = true;

    _timer?.cancel();
    _timer = null;

    _pendingValue = null;
    _hasPendingValue = false;

    final activeWrite = _activeWrite;

    if (activeWrite != null) {
      try {
        await activeWrite;
      } catch (_) {}
    }
  }
}

class DriverTrackingResult {
  const DriverTrackingResult.started() : message = null;

  const DriverTrackingResult.failure(this.message);

  final String? message;

  bool get isStarted => message == null;
}
