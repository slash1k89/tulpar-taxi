import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'tulpar_api_client.dart';
import 'locale_controller.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, TulparApiClient? apiClient})
    : _auth = auth ?? FirebaseAuth.instance,
      _apiClient = apiClient ?? TulparApiClient();

  final FirebaseAuth _auth;
  final TulparApiClient _apiClient;

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

      final result = await _auth.createUserWithEmailAndPassword(
        email: fakeEmail,
        password: password,
      );

      createdUser = result.user;

      if (createdUser == null) {
        return 'е удалось создать аккаунт';
      }

      await _apiClient.syncCurrentUser(name: name.trim(), phone: phone.trim());
      unawaited(appLocaleController.syncIfAuthenticated());

      return null;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        return 'ользователь с таким номером уже существует';
      }

      if (error.code == 'weak-password') {
        return 'ароль должен быть не менее 6 символов';
      }

      return 'Ошибка авторизации: ${error.message ?? error.code}';
    } on TulparApiException catch (error) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }

      if (error.statusCode == 409) {
        return 'ользователь с таким номером уже существует';
      }

      return 'е удалось создать профиль: ${error.message}';
    } catch (_) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }

      return 'е удалось создать профиль. опробуйте ещё раз.';
    }
  }

  Future<String?> loginUser({
    required String phone,
    required String password,
  }) async {
    try {
      final cleanPhone = _cleanPhone(phone);
      final fakeEmail = '$cleanPhone@tulpar.kz';

      await _auth.signInWithEmailAndPassword(
        email: fakeEmail,
        password: password,
      );

      // беспечиваем наличие пользователя в PostgreSQL даже для старого
      // Firebase-аккаунта, созданного до перехода на VPS.
      await _apiClient.syncCurrentUser(phone: phone.trim());
      unawaited(appLocaleController.syncIfAuthenticated());

      return null;
    } on FirebaseAuthException {
      return 'еверный номер телефона или пароль';
    } on TulparApiException catch (error) {
      return 'е удалось синхронизировать профиль: ${error.message}';
    } catch (error) {
      return 'шибка авторизации: $error';
    }
  }
}
