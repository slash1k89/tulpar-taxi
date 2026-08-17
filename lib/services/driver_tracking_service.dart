import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

const _useCloudFunctions = bool.fromEnvironment('USE_CLOUD_FUNCTIONS');

class DriverTrackingService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<Position>? _positionStreamSubscription;
  DateTime? _lastFirestoreWrite;

  Future<DriverTrackingResult> startLocationUpdates(String orderId) async {
    final user = _auth.currentUser;
    if (user == null) return const DriverTrackingResult.failure('Войдите в аккаунт водителя.');

    // Проверяем, включены ли службы геолокации
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return const DriverTrackingResult.failure('Включите службы геолокации.');

    // Проверяем разрешения
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const DriverTrackingResult.failure('Разрешите доступ к геолокации.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const DriverTrackingResult.failure('Доступ к геолокации отключён в настройках.');
    }

    final driverRef = _dbRef.child('active_order_locations/$orderId/${user.uid}');
    final trackingRef = _firestore
        .collection('orders')
        .doc(orderId)
        .collection('tracking')
        .doc('current');

    if (_useCloudFunctions) await driverRef.onDisconnect().remove();

    try {
      final position = await Geolocator.getCurrentPosition();
      await _writePosition(driverRef, trackingRef, position);
    } catch (_) {
      return const DriverTrackingResult.failure('Не удалось получить текущую геопозицию.');
    }

    // Слушаем перемещения
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _useCloudFunctions ? 5 : 20,
      ),
    ).listen(
      (position) => _writePosition(driverRef, trackingRef, position),
      onError: (_) {},
    );

    return const DriverTrackingResult.started();
  }

  Future<void> _writePosition(
    DatabaseReference databaseRef,
    DocumentReference<Map<String, dynamic>> firestoreRef,
    Position position,
  ) async {
    if (_useCloudFunctions) {
      await databaseRef.set({
      'lat': position.latitude,
      'lng': position.longitude,
      'lastUpdated': ServerValue.timestamp,
      });
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
    final user = _auth.currentUser;
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    _lastFirestoreWrite = null;
    if (user != null && _useCloudFunctions) {
      await _dbRef.child('active_order_locations/$orderId/${user.uid}').remove();
    }
  }
}

class DriverTrackingResult {
  const DriverTrackingResult.started() : message = null;
  const DriverTrackingResult.failure(this.message);

  final String? message;
  bool get isStarted => message == null;
}
