import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../firebase_options.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/map/order_tracking_screen.dart';
import 'tulpar_api_client.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    TulparApiClient? apiClient,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _apiClient = apiClient ?? TulparApiClient();

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final TulparApiClient _apiClient;
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
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      _saveTokenForCurrentUser,
    );
    FirebaseMessaging.onMessage.listen((message) {
      if (_isDriverArrived(message)) {
        // OrderTrackingScreen observes the order status itself. Showing an
        // additional foreground banner would only cover the map.
        return;
      }

      SystemSound.play(SystemSoundType.alert);

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
      (message) => _openFromMessage(navigatorKey, message),
    );
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openFromMessage(navigatorKey, initialMessage),
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
    try {
      await _apiClient.registerPushToken(token: token, platform: 'android');
      debugPrint('[PushToken] token registered on VPS');
    } catch (error, stackTrace) {
      debugPrint('[PushToken] failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _isDriverArrived(RemoteMessage message) {
    return message.data['type']?.toString() == 'driver_arrived';
  }

  void _openFromMessage(
    GlobalKey<NavigatorState> navigatorKey,
    RemoteMessage message,
  ) {
    final orderId = message.data['orderId'];
    if (orderId is String && orderId.isNotEmpty) {
      if (_isDriverArrived(message)) {
        _openOrderTracking(navigatorKey, orderId);
        return;
      }
      _openChat(navigatorKey, orderId);
    }
  }

  void _openOrderTracking(
    GlobalKey<NavigatorState> navigatorKey,
    String orderId,
  ) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: orderId)),
    );
  }

  void _openChat(GlobalKey<NavigatorState> navigatorKey, String orderId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(orderId: orderId, peerName: 'Чат'),
      ),
    );
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
  }
}
