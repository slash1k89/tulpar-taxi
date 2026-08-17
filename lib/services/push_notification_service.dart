import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../screens/chat/chat_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<User?>? _authSubscription;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required GlobalKey<ScaffoldMessengerState> messengerKey,
  }) async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) _saveCurrentToken(user.uid);
    });
    _tokenSubscription = _messaging.onTokenRefresh.listen(_saveTokenForCurrentUser);
    FirebaseMessaging.onMessage.listen((message) {
      final orderId = message.data['orderId'];
      final body = message.notification?.body ?? 'Новое сообщение в чате';
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(body),
          action: orderId is String
              ? SnackBarAction(
                  label: 'Открыть',
                  onPressed: () => _openChat(navigatorKey, orderId),
                )
              : null,
        ),
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _openChatFromMessage(navigatorKey, message),
    );
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openChatFromMessage(navigatorKey, initialMessage),
      );
    }
  }

  Future<void> _saveCurrentToken(String uid) async {
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(uid, token);
  }

  Future<void> _saveTokenForCurrentUser(String token) async {
    final user = _auth.currentUser;
    if (user != null) await _saveToken(user.uid, token);
  }

  Future<void> _saveToken(String uid, String token) async {
    final tokenRef = _firestore.collection('users').doc(uid).collection('fcmTokens').doc(token);
    final existing = await tokenRef.get();
    if (existing.exists) {
      await tokenRef.update({'updatedAt': FieldValue.serverTimestamp()});
      return;
    }

    await tokenRef.set({
      'token': token,
      'platform': 'android',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _openChatFromMessage(GlobalKey<NavigatorState> navigatorKey, RemoteMessage message) {
    final orderId = message.data['orderId'];
    if (orderId is String && orderId.isNotEmpty) _openChat(navigatorKey, orderId);
  }

  void _openChat(GlobalKey<NavigatorState> navigatorKey, String orderId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ChatScreen(orderId: orderId, peerName: 'Чат')),
    );
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
  }
}
