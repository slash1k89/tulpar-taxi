import 'package:firebase_auth/firebase_auth.dart';

import 'tulpar_auth_session.dart';

class AppIdentityService {
  AppIdentityService({
    TulparAuthController? tulparAuth,
    FirebaseAuth? firebaseAuth,
  }) : _tulparAuth = tulparAuth ?? TulparAuthController.instance,
       _firebaseAuth = firebaseAuth;

  final TulparAuthController _tulparAuth;
  final FirebaseAuth? _firebaseAuth;

  FirebaseAuth? get _legacyAuth {
    if (_firebaseAuth != null) return _firebaseAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated =>
      _tulparAuth.hasSession || _legacyAuth?.currentUser != null;

  String? get currentUserId =>
      _tulparAuth.currentUserId ?? _legacyAuth?.currentUser?.uid;

  Future<void> signOut() async {
    if (_tulparAuth.hasSession) await _tulparAuth.logout();
    final firebaseAuth = _legacyAuth;
    if (firebaseAuth != null && firebaseAuth.currentUser != null) {
      await firebaseAuth.signOut();
    }
  }
}
