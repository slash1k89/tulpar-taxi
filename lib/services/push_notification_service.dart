import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_routes.dart';
import '../firebase_options.dart';
import '../models/order_service_type.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/intercity/intercity_ride_details_screen.dart';
import '../screens/driver/intercity_driver_ride_details_screen.dart';
import '../screens/map/order_tracking_screen.dart';
import 'driver_approaching_notification.dart';
import 'intercity_ride_service.dart';
import 'tulpar_api_client.dart';
import 'tulpar_auth_session.dart';
import 'push_token_registration.dart';
import 'navigation_audio_service.dart';
import 'navigation_voice_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  pushDiagnostic(
    'background message type=${message.data['type']} orderId=${message.data['orderId']}',
  );
}

class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    TulparApiClient? apiClient,
    TulparAuthController? tulparAuth,
    this.foregroundMessages,
    this.openedMessages,
    this.backgroundRegistrar,
    this.tokenOwnerId,
    this.readTokenOwner,
    this.writeTokenOwner,
    NavigationAudioOutput? approachingAudio,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _tulparAuth = tulparAuth ?? TulparAuthController.instance,
       _apiClient = apiClient ?? TulparApiClient(),
       _approachingAudio =
           approachingAudio ??
           NavigationAudioService(
             fallbackSpeaker: SystemNavigationVoiceSpeaker(),
           );

  final NavigationAudioOutput _approachingAudio;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final TulparAuthController _tulparAuth;
  final TulparApiClient _apiClient;
  final Stream<RemoteMessage>? foregroundMessages;
  final Stream<RemoteMessage>? openedMessages;
  final VoidCallback? backgroundRegistrar;
  final String? Function()? tokenOwnerId;
  final Future<String?> Function()? readTokenOwner;
  final Future<void> Function(String?)? writeTokenOwner;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  late PushTokenRegistration _tokens;
  late GlobalKey<NavigatorState> _navigatorKey;
  late GlobalKey<ScaffoldMessengerState> _messengerKey;
  final List<RemoteMessage> _pendingForeground = [];
  Timer? _bannerRetry;
  final Set<String> _shownApproaching = {};
  bool _initialized = false;
  bool _disposed = false;
  bool _usingTulparSession = false;
  String? _observedUserId;
  final Map<String, int> _latestOrderStatusRanks = {};

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required GlobalKey<ScaffoldMessengerState> messengerKey,
  }) async {
    if (_initialized || _disposed) return;
    _navigatorKey = navigatorKey;
    _messengerKey = messengerKey;
    pushDiagnostic('firebase initialized; attaching listeners');
    _tokens = PushTokenRegistration(
      currentUserId: _currentPushUserId,
      getToken: _messaging.getToken,
      deleteToken: _messaging.deleteToken,
      register: (token, owner) => _apiClient.registerPushToken(
        token: token,
        expectedUserId: owner,
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      ),
      readOwner:
          readTokenOwner ??
          () async => (await SharedPreferences.getInstance()).getString(
            'push_token_owner',
          ),
      writeOwner:
          writeTokenOwner ??
          (owner) async {
            final prefs = await SharedPreferences.getInstance();
            if (owner == null) {
              await prefs.remove('push_token_owner');
            } else {
              await prefs.setString('push_token_owner', owner);
            }
          },
    );
    _initialized = true;
    (backgroundRegistrar ??
        () => FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        ))();
    _observedUserId = _currentPushUserId();
    // Attach before any permission, getToken, or backend network awaits.
    _foregroundSubscription =
        (foregroundMessages ?? FirebaseMessaging.onMessage).listen(
          _receiveForeground,
        );
    _openedSubscription =
        (openedMessages ?? FirebaseMessaging.onMessageOpenedApp).listen(
          (message) => _openFromMessage(_navigatorKey, message),
        );
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) {
        pushDiagnostic('onTokenRefresh suffix=${pushTokenSuffix(token)}');
        unawaited(_tokens.sync());
      },
      onError: (Object e) {
        pushDiagnostic('onTokenRefresh failure type=${e.runtimeType}');
        unawaited(_tokens.sync());
      },
    );
    _authSubscription = _auth.authStateChanges().listen(
      (_) => _onTulparAuthChanged(),
    );
    _tulparAuth.addListener(_onTulparAuthChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_tokens.sync());
    unawaited(_requestPermission());
    unawaited(_readInitialMessage());
  }

  Future<void> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      pushDiagnostic('permission status=${settings.authorizationStatus.name}');
    } catch (e) {
      pushDiagnostic('permission failure type=${e.runtimeType}');
    }
  }

  Future<void> _readInitialMessage() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null && !_disposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) _openFromMessage(_navigatorKey, initialMessage);
        });
        WidgetsBinding.instance.scheduleFrame();
      }
    } catch (e) {
      pushDiagnostic('initial message failure type=${e.runtimeType}');
    }
  }

  void _receiveForeground(RemoteMessage message) {
    if (_disposed) return;
    pushDiagnostic(
      'foreground message type=${message.data['type']} orderId=${message.data['orderId']}',
    );
    _pendingForeground.add(message);
    _flushForeground();
  }

  void _flushForeground() {
    if (_disposed) return;
    if (_messengerKey.currentState == null) {
      _bannerRetry?.cancel();
      _bannerRetry = Timer(const Duration(milliseconds: 250), _flushForeground);
      return;
    }
    _bannerRetry?.cancel();
    while (_pendingForeground.isNotEmpty) {
      final message = _pendingForeground.first;
      try {
        _handleForeground(message);
        _pendingForeground.removeAt(0);
      } on FlutterError catch (error) {
        // A messenger can exist before its first Scaffold is registered.
        if (!error.toString().contains('no descendant Scaffolds')) rethrow;
        pushDiagnostic('foreground queued: scaffold_not_ready');
        _bannerRetry = Timer(
          const Duration(milliseconds: 250),
          _flushForeground,
        );
        return;
      }
    }
  }

  void _handleForeground(RemoteMessage message) {
    final navigatorKey = _navigatorKey;
    final messengerKey = _messengerKey;
    final eventType = message.data['type']?.toString();
    final orderId = message.data['orderId'];
    if (isDriverApproachingPickup(eventType)) {
      if (orderId is! String ||
          orderId.isEmpty ||
          _currentPushUserId() == null) {
        pushDiagnostic(
          'driver_approaching skipped: missing_orderId_or_signed_out',
        );
        return;
      }
      if (_shownApproaching.contains(orderId) ||
          (_latestOrderStatusRanks[orderId] ?? 0) >= 2) {
        pushDiagnostic(
          'driver_approaching skipped: duplicate_or_later_status orderId=$orderId',
        );
        return;
      }
      messengerKey.currentState!.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 7),
          content: const Text(
            '$driverApproachingPickupTitle\n$driverApproachingPickupBody',
          ),
          action: SnackBarAction(
            label: 'Открыть',
            onPressed: () => _openOrderTracking(navigatorKey, orderId),
          ),
        ),
      );
      _shownApproaching.add(orderId);
      unawaited(
        _approachingAudio.play(
          const NavigationAudioCue(
            assetPaths: ['audio/navigation/order_new.mp3'],
            fallbackText: 'Водитель подъезжает',
          ),
        ),
      );
      pushDiagnostic(
        'driver_approaching handled: foreground banner orderId=$orderId',
      );
      return;
    }
    if (isIntercityRidePushEvent(eventType)) {
      SystemSound.play(SystemSoundType.alert);
      final passengerTarget = intercityPassengerPushTarget(message.data);
      final driverTarget = intercityDriverPushTarget(message.data);
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            message.notification?.body ?? intercityRidePushBody(eventType),
          ),
          action:
              passengerTarget == IntercityPassengerPushTarget.none &&
                  driverTarget == IntercityDriverPushTarget.none
              ? null
              : SnackBarAction(
                  label: 'Открыть',
                  onPressed: () => _openIntercityTarget(
                    navigatorKey,
                    passengerTarget,
                    driverTarget,
                    message.data,
                  ),
                ),
        ),
      );
      return;
    }
    if (_isOrderStatus(message)) {
      if (orderId is String && orderId.isNotEmpty) {
        final nextRank = orderStatusRank(eventType);
        final previousRank = _latestOrderStatusRanks[orderId];
        if (!shouldAcceptOrderStatusEvent(
          previousRank: previousRank,
          eventType: eventType,
        )) {
          return;
        }
        if (nextRank != null) _latestOrderStatusRanks[orderId] = nextRank;
      }

      messengerKey.currentState?.hideCurrentSnackBar();
      if (!shouldShowForegroundPushBanner(eventType)) return;
    }

    SystemSound.play(SystemSoundType.alert);

    final body = passengerPushBody(
      eventType: eventType,
      serviceType: message.data['serviceType'],
      fallbackBody: message.notification?.body,
    );
    final title = passengerPushTitle(
      eventType: eventType,
      fallbackTitle: message.notification?.title,
    );
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(title == null ? body : '$title\n$body'),
        action: orderId is String
            ? SnackBarAction(
                label: 'Открыть',
                onPressed: () => _opensOrderTracking(message)
                    ? _openOrderTracking(navigatorKey, orderId)
                    : _openChat(navigatorKey, orderId),
              )
            : null,
      ),
    );
  }

  void _onTulparAuthChanged() {
    final userId = _currentPushUserId();
    if (userId != _observedUserId) {
      _latestOrderStatusRanks.clear();
      _shownApproaching.clear();
      _pendingForeground.clear();
      _observedUserId = userId;
    }
    unawaited(_tokens.sync());
  }

  String? _currentPushUserId() {
    if (tokenOwnerId != null) return tokenOwnerId!();
    if (_tulparAuth.hasSession) {
      _usingTulparSession = true;
      return _tulparAuth.currentUserId;
    }
    // Do not bind a logged-out Tulpar device to a leftover legacy Firebase user.
    return _usingTulparSession ? null : _auth.currentUser?.uid;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_disposed) {
      unawaited(_tokens.sync());
    }
  }

  bool _isOrderStatus(RemoteMessage message) {
    return const {
      'accepted',
      'arrived',
      'driver_arrived',
      'in_progress',
      'completed',
      'cancelled',
      'expired',
    }.contains(message.data['type']?.toString());
  }

  bool _opensOrderTracking(RemoteMessage message) {
    return _isOrderStatus(message) ||
        driverApproachingOpensOrderTracking(message.data['type']);
  }

  void _openFromMessage(
    GlobalKey<NavigatorState> navigatorKey,
    RemoteMessage message,
  ) {
    final eventType = message.data['type']?.toString();
    if (isIntercityRidePushEvent(eventType)) {
      _openIntercityTarget(
        navigatorKey,
        intercityPassengerPushTarget(message.data),
        intercityDriverPushTarget(message.data),
        message.data,
      );
      return;
    }
    final orderId = message.data['orderId'];
    if (orderId is String && orderId.isNotEmpty) {
      if (_opensOrderTracking(message)) {
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

  void _openIntercityTarget(
    GlobalKey<NavigatorState> navigatorKey,
    IntercityPassengerPushTarget passengerTarget,
    IntercityDriverPushTarget driverTarget,
    Map<String, dynamic> data,
  ) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    switch (driverTarget) {
      case IntercityDriverPushTarget.rideDetails:
        final rideId = data['rideId']?.toString() ?? '';
        if (rideId.isEmpty) {
          navigator.pushNamed(AppRoutes.driverIntercityRides);
          return;
        }
        navigator.push(
          MaterialPageRoute(
            builder: (_) => IntercityDriverRideDetailsScreen(
              rideId: rideId,
              repository: IntercityRideService(),
            ),
          ),
        );
        return;
      case IntercityDriverPushTarget.rides:
        navigator.pushNamed(AppRoutes.driverIntercityRides);
        return;
      case IntercityDriverPushTarget.none:
        break;
    }
    switch (passengerTarget) {
      case IntercityPassengerPushTarget.rideDetails:
        final rideId = data['rideId']?.toString() ?? '';
        if (rideId.isEmpty) return;
        navigator.push(
          MaterialPageRoute(
            builder: (_) => IntercityRideDetailsScreen(
              repository: IntercityRideService(),
              rideId: rideId,
            ),
          ),
        );
      case IntercityPassengerPushTarget.bookings:
        navigator.pushNamed(AppRoutes.intercityBookings);
      case IntercityPassengerPushTarget.requests:
        navigator.pushNamed(AppRoutes.intercityRequests);
      case IntercityPassengerPushTarget.none:
        return;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _bannerRetry?.cancel();
    _pendingForeground.clear();
    WidgetsBinding.instance.removeObserver(this);
    if (_initialized) _tokens.dispose();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
    _tulparAuth.removeListener(_onTulparAuthChanged);
    await _approachingAudio.dispose();
  }
}

enum IntercityPassengerPushTarget { rideDetails, bookings, requests, none }

enum IntercityDriverPushTarget { rideDetails, rides, none }

bool isIntercityRidePushEvent(Object? eventType) =>
    eventType?.toString().startsWith('intercity_') == true;

IntercityPassengerPushTarget intercityPassengerPushTarget(
  Map<String, dynamic> data,
) => switch (data['type']?.toString()) {
  'intercity_ride_match_available' =>
    data['rideId']?.toString().isNotEmpty == true
        ? IntercityPassengerPushTarget.rideDetails
        : IntercityPassengerPushTarget.requests,
  'intercity_ride_cancelled' ||
  'intercity_ride_departed' => IntercityPassengerPushTarget.bookings,
  _ => IntercityPassengerPushTarget.none,
};

IntercityDriverPushTarget intercityDriverPushTarget(
  Map<String, dynamic> data,
) => switch (data['type']?.toString()) {
  'intercity_ride_booked' || 'intercity_booking_cancelled' =>
    data['rideId']?.toString().isNotEmpty == true
        ? IntercityDriverPushTarget.rideDetails
        : IntercityDriverPushTarget.rides,
  _ => IntercityDriverPushTarget.none,
};

String intercityRidePushBody(Object? eventType) =>
    switch (eventType?.toString()) {
      'intercity_ride_match_available' => 'Появилась подходящая попутка',
      'intercity_ride_cancelled' => 'Водитель отменил попутку',
      'intercity_ride_departed' => 'Попутка отправилась',
      'intercity_ride_booked' => 'Новое бронирование попутки',
      'intercity_booking_cancelled' => 'Бронирование попутки отменено',
      _ => 'Новое уведомление о попутке',
    };

int? orderStatusRank(Object? eventType) => switch (eventType?.toString()) {
  'accepted' => 1,
  'arrived' || 'driver_arrived' => 2,
  'in_progress' => 3,
  'completed' || 'cancelled' || 'expired' => 4,
  _ => null,
};

bool shouldAcceptOrderStatusEvent({
  required int? previousRank,
  required Object? eventType,
}) {
  final nextRank = orderStatusRank(eventType);
  return nextRank != null && (previousRank == null || nextRank > previousRank);
}

bool shouldShowForegroundPushBanner(Object? eventType) {
  if (isDriverApproachingPickup(eventType)) {
    return driverApproachingShowsForeground(eventType);
  }
  return eventType != 'arrived' && eventType != 'driver_arrived';
}

String? passengerPushTitle({
  required Object? eventType,
  String? fallbackTitle,
}) => isDriverApproachingPickup(eventType)
    ? driverApproachingPickupTitle
    : fallbackTitle;

String passengerPushBody({
  required Object? eventType,
  required Object? serviceType,
  String? fallbackBody,
}) {
  final type = OrderServiceType.fromValue(serviceType);
  if (isDriverApproachingPickup(eventType)) return driverApproachingPickupBody;
  return switch (eventType?.toString()) {
    driverApproachingPickupEvent => driverApproachingPickupBody,
    'accepted' => type.passengerAcceptedText,
    'arrived' || 'driver_arrived' => type.passengerArrivedText,
    'in_progress' => type.passengerInProgressText,
    'completed' => type.passengerCompletedText,
    _ => fallbackBody ?? 'Новое сообщение в чате',
  };
}
