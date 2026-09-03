import 'dart:async';
import 'package:flutter/foundation.dart';

void pushDiagnostic(String message) {
  if (kDebugMode) debugPrint('[Push] $message');
}

String pushTokenSuffix(String token) =>
    token.length > 6 ? token.substring(token.length - 6) : '<short-token>';

/// Serializes registration and account changes without touching auth semantics.
class PushTokenRegistration {
  PushTokenRegistration({
    required this.currentUserId,
    required this.getToken,
    required this.deleteToken,
    required this.register,
    required this.readOwner,
    required this.writeOwner,
    this.retryDelay = const Duration(seconds: 30),
  });
  final String? Function() currentUserId;
  final Future<String?> Function() getToken;
  final Future<void> Function() deleteToken;
  final Future<void> Function(String token, String userId) register;
  final Future<String?> Function() readOwner;
  final Future<void> Function(String?) writeOwner;
  final Duration retryDelay;
  String? _lastOwner;
  String? _registeredToken;
  String? _registeredOwner;
  bool _ownerLoaded = false;
  bool _disposed = false;
  bool _again = false;
  Future<void>? _work;
  Timer? _retry;

  Future<void> sync() {
    if (_disposed) return Future.value();
    _again = true;
    if (_work != null) return _work!;
    _retry?.cancel();
    return _work = Future<void>(() async {
      try {
        do {
          _again = false;
          try {
            await _syncOnce();
          } catch (e) {
            // Exception bodies may contain credentials. Log type, never tokens.
            pushDiagnostic(
              'token registration failure type=${e.runtimeType}; retry in ${retryDelay.inSeconds}s',
            );
            if (!_disposed) _retry = Timer(retryDelay, () => unawaited(sync()));
          }
        } while (_again && !_disposed);
      } finally {
        _work = null;
      }
    });
  }

  Future<void> _syncOnce() async {
    if (!_ownerLoaded) {
      _lastOwner = await readOwner();
      _ownerLoaded = true;
    }
    if (_disposed) return;
    final userId = currentUserId();
    if (_lastOwner != null && _lastOwner != userId) {
      await deleteToken();
      await writeOwner(null);
      _lastOwner = null;
      _registeredOwner = null;
      _registeredToken = null;
      pushDiagnostic('previous account device token invalidated');
    }
    if (_disposed) return;
    if (userId != currentUserId()) {
      _again = true;
      return;
    }
    if (userId == null) {
      pushDiagnostic('token registration skipped: signed_out');
      return;
    }
    // Remember the signed-in device owner even if getToken fails or logout
    // happens while it is pending; that token must then be invalidated.
    await writeOwner(userId);
    _lastOwner = userId;
    if (_disposed) return;
    if (userId != currentUserId()) {
      _again = true;
      return;
    }
    final token = await getToken().timeout(const Duration(seconds: 12));
    if (_disposed) return;
    if (userId != currentUserId()) {
      _again = true;
      return;
    }
    if (token == null || token.isEmpty) throw StateError('Token unavailable');
    pushDiagnostic(
      'token available suffix=${pushTokenSuffix(token)} userId=$userId',
    );
    if (_registeredOwner == userId && _registeredToken == token) return;
    // The backend derives the owner from auth, never from request body.
    await register(token, userId);
    if (_disposed) return;
    if (userId != currentUserId()) {
      _again = true;
      return;
    }
    _registeredOwner = userId;
    _registeredToken = token;
    _retry?.cancel();
    pushDiagnostic(
      'token registration success userId=$userId suffix=${pushTokenSuffix(token)}',
    );
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
  }
}
