import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const activeOrderStatuses = {'searching', 'accepted', 'arrived', 'in_progress'};

class ActiveOrder {
  const ActiveOrder({
    required this.orderId,
    required this.isDriver,
    required this.data,
  });

  final String orderId;
  final bool isDriver;
  final Map<String, dynamic> data;
}

/// Resolves a user's active ride without changing legacy order documents.
class ActiveOrderService {
  ActiveOrderService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<ActiveOrder?> findCurrentOrder() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final binding = await _firestore
          .collection('active_orders')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));
      final data = binding.data();
      final orderId = data?['orderId'];
      final role = data?['role'];
      if (orderId is String && (role == 'passenger' || role == 'driver')) {
        final active = await _readActiveOrder(orderId, role == 'driver');
        if (active != null) return active;
      }
    } catch (_) {
      // A missing network connection must not block application navigation.
      return null;
    }

    // Compatibility only: old test orders did not create active_orders docs.
    // This is intentionally read-only and never migrates or deletes data.
    return _findLegacyOrder(user.uid);
  }

  Future<ActiveOrder?> _readActiveOrder(String orderId, bool isDriver) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .doc(orderId)
          .get()
          .timeout(const Duration(seconds: 5));
      final data = snapshot.data();
      if (data == null || !activeOrderStatuses.contains(data['status'])) return null;
      final userId = _auth.currentUser?.uid;
      if (userId == null || (isDriver ? data['driverId'] : data['passengerId']) != userId) {
        return null;
      }
      return ActiveOrder(orderId: snapshot.id, isDriver: isDriver, data: data);
    } catch (_) {
      return null;
    }
  }

  Future<ActiveOrder?> _findLegacyOrder(String userId) async {
    try {
      final results = await Future.wait([
        _firestore
            .collection('orders')
            .where('driverId', isEqualTo: userId)
            .get(),
        _firestore
            .collection('orders')
            .where('passengerId', isEqualTo: userId)
            .get(),
      ]).timeout(const Duration(seconds: 5));
      for (var index = 0; index < results.length; index++) {
        final docs = results[index].docs.where(
          (doc) => activeOrderStatuses.contains(doc.data()['status']),
        );
        if (docs.isNotEmpty) {
          return ActiveOrder(
            orderId: docs.first.id,
            isDriver: index == 0,
            data: docs.first.data(),
          );
        }
      }
    } catch (_) {
      // Legacy data is optional; offline startup continues to the map.
    }
    return null;
  }
}
