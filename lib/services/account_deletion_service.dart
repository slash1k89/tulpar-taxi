import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'driver_agreement_service.dart';
import 'tulpar_api_client.dart';
import 'tulpar_auth_session.dart';

enum AccountDeletionOutcome { deleted, pending }

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.code, this.message);

  final String code;
  final String message;
}

abstract interface class AccountReauthenticationGateway {
  String? get currentUserId;
  Future<void> reauthenticate(String password);
  Future<void> forceRefreshIdToken();
  Future<void> signOut();
}

class FirebaseAccountReauthenticationGateway
    implements AccountReauthenticationGateway {
  FirebaseAccountReauthenticationGateway([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw const AccountDeletionException(
        'user_not_found',
        'Не удалось подтвердить текущий аккаунт.',
      );
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseReauthenticationError(error.code);
    }
  }

  @override
  Future<void> forceRefreshIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountDeletionException(
        'user_not_found',
        'Пользователь не авторизован.',
      );
    }
    await user.getIdToken(true);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

AccountDeletionException _mapFirebaseReauthenticationError(String code) {
  return switch (code) {
    'wrong-password' || 'invalid-credential' => const AccountDeletionException(
      'wrong_password',
      'Неверный пароль.',
    ),
    'too-many-requests' => const AccountDeletionException(
      'too_many_requests',
      'Слишком много попыток. Попробуйте позже.',
    ),
    'network-request-failed' => const AccountDeletionException(
      'network_error',
      'Нет соединения с сетью. Попробуйте ещё раз.',
    ),
    'user-disabled' => const AccountDeletionException(
      'user_disabled',
      'Этот аккаунт отключён.',
    ),
    'user-not-found' => const AccountDeletionException(
      'user_not_found',
      'Аккаунт не найден.',
    ),
    'requires-recent-login' => const AccountDeletionException(
      'recent_login_required',
      'Требуется повторный вход в аккаунт.',
    ),
    _ => const AccountDeletionException(
      'reauthentication_failed',
      'Не удалось подтвердить пароль.',
    ),
  };
}

abstract interface class AccountDeletionController {
  Future<AccountDeletionOutcome> deleteWithPassword(String password);
}

class DefaultAccountDeletionController implements AccountDeletionController {
  DefaultAccountDeletionController({
    AccountReauthenticationGateway? reauthentication,
    TulparApiClient? apiClient,
    DriverAgreementService? agreementService,
    Future<void> Function()? clearPushToken,
  }) : _reauthentication =
           reauthentication ?? FirebaseAccountReauthenticationGateway(),
       _apiClient = apiClient ?? TulparApiClient(),
       _agreementService = agreementService ?? DriverAgreementService(),
       _clearPushToken =
           clearPushToken ?? (() => FirebaseMessaging.instance.deleteToken());

  final AccountReauthenticationGateway _reauthentication;
  final TulparApiClient _apiClient;
  final DriverAgreementService _agreementService;
  final Future<void> Function() _clearPushToken;

  @override
  Future<AccountDeletionOutcome> deleteWithPassword(String password) async {
    if (password.isEmpty) {
      throw const AccountDeletionException(
        'empty_password',
        'Введите текущий пароль.',
      );
    }
    final tulparSession = TulparAuthController.instance.hasSession;
    final userId = tulparSession
        ? TulparAuthController.instance.currentUserId
        : _reauthentication.currentUserId;
    if (userId == null) {
      throw const AccountDeletionException(
        'user_not_found',
        'Пользователь не авторизован.',
      );
    }

    if (!tulparSession) {
      await _reauthentication.reauthenticate(password);
      await _reauthentication.forceRefreshIdToken();
    }

    try {
      final response = await _apiClient.deleteCurrentAccount(
        password: tulparSession ? password : null,
      );
      final status = response['status']?.toString();
      if (status != 'deleted' && status != 'deletion_pending') {
        throw const AccountDeletionException(
          'invalid_response',
          'Сервер вернул некорректный ответ.',
        );
      }

      await _bestEffortCleanup(
        'agreement',
        () => _agreementService.clearAcceptance(userId),
      );
      await _bestEffortCleanup('push', _clearPushToken);
      await _bestEffortCleanup(
        'signout',
        tulparSession
            ? TulparAuthController.instance.clearLocalSession
            : _reauthentication.signOut,
      );
      return status == 'deleted'
          ? AccountDeletionOutcome.deleted
          : AccountDeletionOutcome.pending;
    } on TimeoutException {
      throw const AccountDeletionException(
        'account_deletion_result_unknown',
        'Не удалось подтвердить ответ сервера. Повторите удаление: повторный запрос безопасен.',
      );
    } on TulparApiException catch (error) {
      final code = error.data?['code']?.toString();
      throw AccountDeletionException(
        code ?? 'backend_error',
        _backendDeletionMessage(code, error.statusCode),
      );
    }
  }

  Future<void> _bestEffortCleanup(
    String step,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      debugPrint('[AccountDeletionCleanup] step=$step status=failed');
    }
  }
}

String _backendDeletionMessage(String? code, int statusCode) {
  return switch (code) {
    'recent_login_required' => 'Подтвердите пароль ещё раз.',
    'active_order' => 'Сначала завершите или отмените текущий заказ.',
    'active_driver_order' => 'Сначала завершите активный заказ водителя.',
    'active_ride' => 'Сначала завершите или отмените поездку «Попутки».',
    'active_booking' => 'Сначала завершите или отмените бронирование.',
    'active_ride_request' => 'Сначала отмените активный запрос «Попутки».',
    'account_deletion_manual_recovery_required' =>
      'Удаление требует проверки службой поддержки.',
    _ when statusCode == 0 => 'Нет соединения с сервером.',
    _ => 'Не удалось удалить аккаунт. Попробуйте ещё раз.',
  };
}
