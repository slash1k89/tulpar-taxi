import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const _useCloudFunctions = bool.fromEnvironment('USE_CLOUD_FUNCTIONS');

class DriverTrackingService {
  static const Duration realtimeDatabaseWriteInterval = Duration(
    milliseconds: 1500,
  );

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<Position>? _positionStreamSubscription;
  DateTime? _lastFirestoreWrite;
  LatestValueWriteThrottler<Position>? _realtimeDatabaseWriter;
  final ValueNotifier<LatLng?> _positionNotifier = ValueNotifier(null);
  bool _isDisposed = false;
  int _trackingSession = 0;

  ValueListenable<LatLng?> get positionListenable => _positionNotifier;
  LatLng? get latestPosition => _positionNotifier.value;

  Future<DriverTrackingResult> startLocationUpdates(String orderId) async {
    if (_isDisposed) {
      return const DriverTrackingResult.failure(
        'Отслеживание геопозиции уже остановлено.',
      );
    }
    final session = ++_trackingSession;

    final user = _auth.currentUser;
    if (user == null) {
      return const DriverTrackingResult.failure('Войдите в аккаунт водителя.');
    }

    // Проверяем, включены ли службы геолокации
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_isSessionActive(session)) {
      return const DriverTrackingResult.failure(
        'Отслеживание геопозиции остановлено.',
      );
    }
    if (!serviceEnabled) {
      return const DriverTrackingResult.failure('Включите службы геолокации.');
    }

    // Проверяем разрешения
    LocationPermission permission = await Geolocator.checkPermission();
    if (!_isSessionActive(session)) {
      return const DriverTrackingResult.failure(
        'Отслеживание геопозиции остановлено.',
      );
    }
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!_isSessionActive(session)) {
        return const DriverTrackingResult.failure(
          'Отслеживание геопозиции остановлено.',
        );
      }
      if (permission == LocationPermission.denied) {
        return const DriverTrackingResult.failure(
          'Разрешите доступ к геолокации.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const DriverTrackingResult.failure(
        'Доступ к геолокации отключён в настройках.',
      );
    }

    final driverRef = _dbRef.child(
      'active_order_locations/$orderId/${user.uid}',
    );
    final trackingRef = _firestore
        .collection('orders')
        .doc(orderId)
        .collection('tracking')
        .doc('current');

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    await _realtimeDatabaseWriter?.close();
    _realtimeDatabaseWriter = null;
    _lastFirestoreWrite = null;
    if (!_isSessionActive(session)) {
      return const DriverTrackingResult.failure(
        'Отслеживание геопозиции остановлено.',
      );
    }

    if (_useCloudFunctions) {
      await driverRef.onDisconnect().remove();
      if (!_isSessionActive(session)) {
        return const DriverTrackingResult.failure(
          'Отслеживание геопозиции остановлено.',
        );
      }
      _realtimeDatabaseWriter = LatestValueWriteThrottler<Position>(
        minimumInterval: realtimeDatabaseWriteInterval,
        write: (position) => driverRef.set({
          'lat': position.latitude,
          'lng': position.longitude,
          'lastUpdated': ServerValue.timestamp,
        }),
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (!_isSessionActive(session)) {
        return const DriverTrackingResult.failure(
          'Отслеживание геопозиции остановлено.',
        );
      }
      _publishPosition(position);
      await _writePosition(trackingRef, position, writeImmediately: true);
    } catch (_) {
      return const DriverTrackingResult.failure(
        'Не удалось получить текущую геопозицию.',
      );
    }

    // Слушаем перемещения
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: _useCloudFunctions ? 5 : 20,
          ),
        ).listen((position) {
          _publishPosition(position);
          unawaited(_writePosition(trackingRef, position).catchError((_) {}));
        }, onError: (_) {});

    return const DriverTrackingResult.started();
  }

  void _publishPosition(Position position) {
    if (_isDisposed) return;
    _positionNotifier.value = LatLng(position.latitude, position.longitude);
  }

  bool _isSessionActive(int session) {
    return !_isDisposed && session == _trackingSession;
  }

  Future<void> _writePosition(
    DocumentReference<Map<String, dynamic>> firestoreRef,
    Position position, {
    bool writeImmediately = false,
  }) async {
    if (_useCloudFunctions) {
      final writer = _realtimeDatabaseWriter;
      if (writer == null) return;
      if (writeImmediately) {
        await writer.writeImmediately(position);
      } else {
        writer.add(position);
      }
      return;
    }

    final now = DateTime.now();
    if (_lastFirestoreWrite != null &&
        now.difference(_lastFirestoreWrite!) < const Duration(seconds: 5)) {
      return;
    }
    _lastFirestoreWrite = now;
    await firestoreRef.set({
      'lat': position.latitude,
      'lng': position.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> stopLocationUpdates(String orderId) async {
    _trackingSession++;
    final user = _auth.currentUser;
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    await _realtimeDatabaseWriter?.close();
    _realtimeDatabaseWriter = null;

    _lastFirestoreWrite = null;
    if (user != null && _useCloudFunctions) {
      await _dbRef
          .child('active_order_locations/$orderId/${user.uid}')
          .remove();
    }
  }

  Future<void> dispose(String orderId) async {
    if (_isDisposed) return;
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
    if (_isClosed) return;
    _pendingValue = value;
    _hasPendingValue = true;
    _scheduleWrite();
  }

  Future<void> writeImmediately(T value) async {
    if (_isClosed) return;
    _pendingValue = value;
    _hasPendingValue = true;
    _timer?.cancel();
    _timer = null;
    if (_isWriteInProgress) return;
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
    unawaited(_flush().catchError((_) {}));
  }

  Future<void> _flush() async {
    if (_isClosed || _isWriteInProgress || !_hasPendingValue) return;

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
      if (!_isClosed) _scheduleWrite();
    }
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    _timer?.cancel();
    _timer = null;
    _pendingValue = null;
    _hasPendingValue = false;

    final activeWrite = _activeWrite;
    if (activeWrite != null) {
      try {
        await activeWrite;
      } catch (_) {
        // The tracking caller already handles write failures.
      }
    }
  }
}

class DriverTrackingResult {
  const DriverTrackingResult.started() : message = null;
  const DriverTrackingResult.failure(this.message);

  final String? message;
  bool get isStarted => message == null;
}
