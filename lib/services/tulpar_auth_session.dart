import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class TulparAuthException implements Exception {
  const TulparAuthException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

@immutable
class TulparAuthSession {
  const TulparAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.userId,
    required this.sessionId,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final String userId;
  final String sessionId;

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt': accessTokenExpiresAt.toUtc().toIso8601String(),
    'userId': userId,
    'sessionId': sessionId,
  };

  static TulparAuthSession? fromJson(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final accessToken = map['accessToken'];
    final refreshToken = map['refreshToken'];
    final expiresAt = DateTime.tryParse(
      map['accessTokenExpiresAt']?.toString() ?? '',
    );
    final userId = map['userId'];
    final sessionId = map['sessionId'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        expiresAt == null ||
        userId is! String ||
        userId.isEmpty ||
        sessionId is! String ||
        sessionId.isEmpty) {
      return null;
    }
    return TulparAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: expiresAt,
      userId: userId,
      sessionId: sessionId,
    );
  }
}

abstract interface class TulparAuthSessionStore {
  Future<TulparAuthSession?> read();
  Future<void> write(TulparAuthSession session);
  Future<void> clear();
}

class SecureTulparAuthSessionStore implements TulparAuthSessionStore {
  SecureTulparAuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'tulpar_auth_session_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<TulparAuthSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return TulparAuthSession.fromJson(jsonDecode(raw));
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(TulparAuthSession session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}

class FlashCallChallenge {
  const FlashCallChallenge({
    required this.challengeId,
    required this.expiresIn,
    required this.resendAfter,
  });

  final String challengeId;
  final int expiresIn;
  final int resendAfter;
}

class FlashCallVerificationResult {
  const FlashCallVerificationResult({required this.profileRequired});

  final bool profileRequired;
}

class PasswordVerificationResult {
  const PasswordVerificationResult({required this.verificationToken});
  final String verificationToken;
}

class TulparAuthController extends ChangeNotifier {
  TulparAuthController({
    TulparAuthSessionStore? store,
    http.Client? client,
    String baseUrl = TulparApiConfig.baseUrl,
    DateTime Function()? now,
  }) : _store = store ?? SecureTulparAuthSessionStore(),
       _client = client ?? http.Client(),
       _baseUrl = baseUrl,
       _now = now ?? DateTime.now;

  static final TulparAuthController instance = TulparAuthController();

  final TulparAuthSessionStore _store;
  final http.Client _client;
  final String _baseUrl;
  final DateTime Function() _now;
  TulparAuthSession? _session;
  Future<String>? _refreshing;
  bool _restored = false;

  TulparAuthSession? get session => _session;
  bool get hasSession => _session != null;
  bool get isRestored => _restored;
  String? get currentUserId => _session?.userId;

  Future<bool> restore() async {
    if (!_restored) {
      _session = await _store.read();
      _restored = true;
      notifyListeners();
    }
    if (_session == null) return false;
    try {
      await validAccessToken();
      return true;
    } catch (_) {
      await clearLocalSession();
      return false;
    }
  }

  Future<FlashCallChallenge> requestFlashCall({
    required String phone,
    String? purpose,
    String? deviceId,
    String? deviceName,
  }) async {
    final body = await _postJson('/api/auth/verification/request', {
      'phone': phone,
      'method': 'flash_call',
      'purpose': purpose ?? 'login',
      if (deviceId?.trim().isNotEmpty == true) 'deviceId': deviceId!.trim(),
      if (deviceName?.trim().isNotEmpty == true)
        'deviceName': deviceName!.trim(),
    });
    return FlashCallChallenge(
      challengeId: _requiredString(body, 'challengeId'),
      expiresIn: _requiredInt(body, 'expiresIn'),
      resendAfter: _requiredInt(body, 'resendAfter'),
    );
  }

  Future<FlashCallVerificationResult> verifyFlashCall({
    required String challengeId,
    required String phone,
    required String code,
    String? deviceId,
    String? deviceName,
  }) async {
    final body = await _postJson('/api/auth/verification/verify', {
      'challengeId': challengeId,
      'phone': phone,
      'code': code,
      if (deviceId?.trim().isNotEmpty == true) 'deviceId': deviceId!.trim(),
      if (deviceName?.trim().isNotEmpty == true)
        'deviceName': deviceName!.trim(),
    });
    await _saveSession(body);
    return FlashCallVerificationResult(
      profileRequired: body['profileRequired'] == true,
    );
  }

  Future<PasswordVerificationResult> verifyPasswordFlashCall({
    required String challengeId,
    required String phone,
    required String code,
    required String purpose,
  }) async {
    final body = await _postJson('/api/auth/verification/verify', {
      'challengeId': challengeId,
      'phone': phone,
      'code': code,
      'purpose': purpose,
    });
    return PasswordVerificationResult(
      verificationToken: _requiredString(body, 'verificationToken'),
    );
  }

  Future<void> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    final body = await _postJson('/api/auth/login', {
      'phone': phone,
      'password': password,
    });
    await _saveSession(body);
  }

  Future<void> setVerifiedPassword({
    required String verificationToken,
    required String password,
    required String purpose,
  }) async {
    final body = await _postJson('/api/auth/password/$purpose', {
      'verificationToken': verificationToken,
      'password': password,
    });
    await _saveSession(body);
  }

  Future<String> validAccessToken({bool forceRefresh = false}) async {
    final current = _session;
    if (current == null) {
      throw const TulparAuthException(
        'not_authenticated',
        'Войдите в аккаунт.',
      );
    }
    final refreshAt = current.accessTokenExpiresAt.subtract(
      const Duration(seconds: 30),
    );
    if (!forceRefresh && _now().isBefore(refreshAt)) {
      return current.accessToken;
    }
    return refreshAccessToken();
  }

  Future<String> refreshAccessToken() {
    final active = _refreshing;
    if (active != null) return active;
    final future = _refreshAccessToken();
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<String> refreshAfterUnauthorized(String rejectedAccessToken) {
    final current = _session;
    if (current == null) {
      throw const TulparAuthException(
        'not_authenticated',
        'Войдите в аккаунт.',
      );
    }
    if (current.accessToken != rejectedAccessToken) {
      return Future.value(current.accessToken);
    }
    return refreshAccessToken();
  }

  Future<String> _refreshAccessToken() async {
    final current = _session;
    if (current == null) {
      throw const TulparAuthException(
        'not_authenticated',
        'Войдите в аккаунт.',
      );
    }
    try {
      final body = await _postJson('/api/auth/refresh', {
        'refreshToken': current.refreshToken,
      });
      await _saveSession(body, userId: current.userId);
      return _session!.accessToken;
    } catch (_) {
      await clearLocalSession();
      rethrow;
    }
  }

  Future<void> logout() async {
    final token = _session?.accessToken;
    try {
      if (token != null) {
        await _postJson('/api/auth/logout', const {}, bearer: token);
      }
    } finally {
      await clearLocalSession();
    }
  }

  Future<void> clearLocalSession() async {
    _session = null;
    await _store.clear();
    notifyListeners();
  }

  Future<void> _saveSession(Map<String, dynamic> body, {String? userId}) async {
    final ttl = _requiredInt(body, 'accessTokenExpiresIn');
    final next = TulparAuthSession(
      accessToken: _requiredString(body, 'accessToken'),
      refreshToken: _requiredString(body, 'refreshToken'),
      accessTokenExpiresAt: _now().add(Duration(seconds: ttl)),
      userId: userId ?? _requiredString(body, 'userId'),
      sessionId: _requiredString(body, 'sessionId'),
    );
    await _store.write(next);
    _session = next;
    _restored = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: {
            'content-type': 'application/json',
            'accept': 'application/json',
            if (bearer != null) 'authorization': 'Bearer $bearer',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));
    Map<String, dynamic> decoded = const {};
    try {
      final value = jsonDecode(response.body);
      if (value is Map) decoded = Map<String, dynamic>.from(value);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TulparAuthException(
        decoded['code']?.toString() ?? 'auth_failed',
        decoded['error']?.toString() ?? 'Не удалось выполнить вход.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  String _requiredString(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value is! String || value.isEmpty) {
      throw const TulparAuthException(
        'invalid_response',
        'Сервер вернул некорректный ответ.',
      );
    }
    return value;
  }

  int _requiredInt(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value is! num || value < 0 || value.toInt() != value) {
      throw const TulparAuthException(
        'invalid_response',
        'Сервер вернул некорректный ответ.',
      );
    }
    return value.toInt();
  }
}
