import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _cleanPhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  Future<String?> registerUser({
    required String name,
    required String phone,
    required String password,
  }) async {
    User? createdUser;

    try {
      final cleanPhone = _cleanPhone(phone);
      final fakeEmail = '$cleanPhone@tulpar.kz';

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: fakeEmail,
        password: password,
      );

      createdUser = result.user;
      if (createdUser == null) {
        return 'Не удалось создать аккаунт';
      }

      await _db.collection('users').doc(createdUser.uid).set({
        'uid': createdUser.uid,
        'name': name.trim(),
        'phone': phone,
        'role': 'passenger',
        'rating': 5.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'Пользователь с таким номером уже существует';
      }
      if (e.code == 'weak-password') {
        return 'Пароль должен быть не менее 6 символов';
      }
      return 'Ошибка Firebase: ${e.message}';
    } catch (e) {
      // Auth и Firestore не образуют общую транзакцию. Если профиль создать
      // не удалось, удаляем только что созданный Auth-аккаунт, чтобы не
      // оставлять пользователя без обязательного users/{uid} профиля.
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {
          // Исходную ошибку профиля показываем пользователю; повторная
          // регистрация тем же номером всё равно сообщит о занятом номере.
        }
      }
      return 'Не удалось создать профиль. Попробуйте ещё раз.';
    }
  }

  Future<String?> loginUser({
    required String phone,
    required String password,
  }) async {
    try {
      final cleanPhone = _cleanPhone(phone);
      final fakeEmail =
          '$cleanPhone@tulpar.kz'; // Исправлено: единый домен проекта

      await _auth.signInWithEmailAndPassword(
        email: fakeEmail,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (_) {
      return 'Неверный номер телефона или пароль';
    } catch (e) {
      return 'Ошибка авторизации: $e';
    }
  }
}
