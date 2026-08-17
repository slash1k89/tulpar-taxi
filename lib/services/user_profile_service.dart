import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.phone,
    required this.averageRating,
    this.carModel = '',
  });

  final String name;
  final String phone;
  final double averageRating;
  final String carModel;
}

abstract interface class UserProfileRepository {
  Future<UserProfile?> load(String userId);

  Future<void> update({
    required String userId,
    required String name,
    required String carModel,
  });
}

class FirebaseUserProfileRepository implements UserProfileRepository {
  FirebaseUserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<UserProfile?> load(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    final data = snapshot.data();
    if (data == null) return null;

    final ratingSum = (data['ratingSum'] as num?)?.toDouble() ?? 0;
    final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
    final fallbackRating = (data['rating'] as num?)?.toDouble() ?? 5;

    return UserProfile(
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      averageRating: ratingCount > 0 ? ratingSum / ratingCount : fallbackRating,
      carModel: data['carModel']?.toString() ?? '',
    );
  }

  @override
  Future<void> update({
    required String userId,
    required String name,
    required String carModel,
  }) {
    return _firestore.collection('users').doc(userId).update({
      'name': name.trim(),
      'carModel': carModel.trim(),
    });
  }
}
