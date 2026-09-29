import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/services/driver_approaching_notification.dart';
import 'package:taxi_esil/services/push_notification_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/services/navigation_audio_service.dart';
import 'package:taxi_esil/screens/chat/chat_screen.dart';
import 'package:taxi_esil/services/chat_notification_service.dart';

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  testWidgets('foreground banner expires and replacement keeps its own timer', (
    tester,
  ) async {
    final rig = _PushRig();
    await tester.pumpWidget(rig.app());
    await rig.initialize();
    rig.foreground.add(
      const RemoteMessage(
        messageId: 'first',
        data: {'type': 'chat_message', 'orderId': 'one', 'messageId': 'first'},
      ),
    );
    await flush(tester);
    expect(find.text('Открыть'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    rig.foreground.add(
      const RemoteMessage(
        messageId: 'second',
        data: {'type': 'chat_message', 'orderId': 'two', 'messageId': 'second'},
      ),
    );
    await flush(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SnackBar), findsOneWidget);
    rig.foreground.add(
      const RemoteMessage(
        messageId: 'third',
        data: {'type': 'order_created', 'orderId': 'three'},
      ),
    );
    await flush(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar), findsNothing);
    rig.dispose();
  });

  testWidgets('duplicate foreground event is not queued twice', (tester) async {
    final rig = _PushRig();
    await tester.pumpWidget(rig.app());
    await rig.initialize();
    const message = RemoteMessage(
      messageId: 'same',
      data: {'type': 'chat_message', 'orderId': 'one', 'messageId': 'same'},
    );
    rig.foreground.add(message);
    rig.foreground.add(message);
    await flush(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar), findsNothing);
    rig.dispose();
  });

  testWidgets('Open removes banner before navigating to chat', (tester) async {
    final rig = _PushRig();
    await tester.pumpWidget(rig.app());
    await rig.initialize();
    rig.foreground.add(
      const RemoteMessage(
        messageId: 'open-one',
        data: {
          'type': 'chat_message',
          'orderId': 'order-open',
          'messageId': 'open-one',
        },
      ),
    );
    await flush(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Открыть'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    rig.dispose();
  });

  testWidgets('message for already open chat does not show a banner', (
    tester,
  ) async {
    final rig = _PushRig();
    await tester.pumpWidget(rig.app());
    await rig.initialize();
    chatNotificationService.openChat('already-open');
    rig.foreground.add(
      const RemoteMessage(
        messageId: 'open-chat-message',
        data: {
          'type': 'chat_message',
          'orderId': 'already-open',
          'messageId': 'open-chat-message',
        },
      ),
    );
    await flush(tester);
    expect(find.byType(SnackBar), findsNothing);
    chatNotificationService.closeChat('already-open');
    rig.dispose();
  });

  testWidgets('disposing while a banner is visible cancels its timer', (
    tester,
  ) async {
    final rig = _PushRig();
    await tester.pumpWidget(rig.app());
    await rig.initialize();
    rig.foreground.add(
      const RemoteMessage(
        messageId: 'dispose-banner',
        data: {
          'type': 'chat_message',
          'orderId': 'one',
          'messageId': 'dispose-banner',
        },
      ),
    );
    await flush(tester);
    rig.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
  testWidgets('canonical and alias duplicates show and sound only once', (
    tester,
  ) async {
    final rig = _PushRig();
    await tester.pumpWidget(rig.app());
    await rig.initialize();
    for (final type in ['driver_approaching_pickup', 'driver_approaching']) {
      rig.foreground.add(RemoteMessage(data: {'type': type, 'orderId': 'one'}));
    }
    await flush(tester);
    expect(rig.audio.calls, 1);
    expect(rig.audio.cues.single.assetPaths, [
      'audio/navigation/ru/driver_approaching.mp3',
    ]);
    expect(find.textContaining(driverApproachingPickupTitle), findsOneWidget);
    rig.foreground.add(
      const RemoteMessage(data: {'type': 'chat', 'orderId': 'other'}),
    );
    await flush(tester);
    expect(rig.audio.calls, 1);
    rig.dispose();
  });

  testWidgets('duplicate intercity booking event shows one foreground banner', (
    tester,
  ) async {
    final rig = _PushRig();
    await tester.pumpWidget(rig.app());
    await rig.initialize();
    const message = RemoteMessage(
      data: {
        'type': 'intercity_booking_created',
        'rideId': 'ride-1',
        'bookingId': 'booking-1',
      },
    );
    rig.foreground.add(message);
    rig.foreground.add(message);
    await flush(tester);
    expect(
      find.text(lookupAppLocalizations(const Locale('ru')).pushIntercityBooked),
      findsOneWidget,
    );

    rig.dispose();
  });

  for (final code in ['ru', 'kk', 'en']) {
    testWidgets('$code approaching and arrived are separate one-shot events', (
      tester,
    ) async {
      final rig = _PushRig();
      await tester.pumpWidget(rig.app(locale: Locale(code)));
      await rig.initialize();
      rig.foreground.add(
        const RemoteMessage(
          data: {'type': 'driver_approaching_pickup', 'orderId': 'one'},
        ),
      );
      await flush(tester);
      expect(rig.audio.cues.last.assetPaths, [
        'audio/navigation/$code/driver_approaching.mp3',
      ]);
      rig.foreground.add(
        const RemoteMessage(data: {'type': 'driver_arrived', 'orderId': 'one'}),
      );
      await flush(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(rig.audio.cues.last.assetPaths, [
        'audio/navigation/$code/order_arrived.mp3',
      ]);
      expect(
        find.textContaining(
          lookupAppLocalizations(Locale(code)).pushDriverArrived,
        ),
        findsOneWidget,
      );
      rig.foreground.add(
        const RemoteMessage(data: {'type': 'arrived', 'orderId': 'one'}),
      );
      await flush(tester);
      expect(rig.audio.calls, 2);
      rig.dispose();
    });
  }

  testWidgets('approaching survives more than ten seconds without UI', (
    tester,
  ) async {
    final rig = _PushRig();
    await rig.initialize();
    rig.foreground.add(
      const RemoteMessage(
        data: {'type': 'driver_approaching_pickup', 'orderId': 'one'},
      ),
    );
    await flush(tester);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpWidget(rig.app());
    await tester.pump(const Duration(milliseconds: 300));
    await flush(tester);
    expect(find.textContaining(driverApproachingPickupTitle), findsOneWidget);
    expect(rig.audio.calls, 1);
    rig.dispose();
  });
  for (final event in [driverApproachingPickupEvent, 'driver_approaching']) {
    testWidgets(
      '$event foreground banner works while permission/token are pending',
      (tester) async {
        final rig = _PushRig();
        await tester.pumpWidget(rig.app());
        await rig.initialize();
        await rig.initialize();
        await flush(tester);
        expect(rig.foregroundSubscriptions, 1);
        expect(rig.backgroundRegistrations, 1);
        expect(rig.messaging.permission.isCompleted, isFalse);
        expect(rig.api.registrations, isEmpty);
        rig.foreground.add(
          RemoteMessage(data: {'type': event, 'orderId': 'order-123'}),
        );
        await flush(tester);
        expect(
          find.textContaining(driverApproachingPickupTitle),
          findsOneWidget,
        );
        expect(
          find.textContaining(driverApproachingPickupBody),
          findsOneWidget,
        );
        expect(find.text('Открыть'), findsOneWidget);
        rig.dispose();
      },
    );
  }

  testWidgets(
    'getToken failure cannot prevent foreground reception; later retry registers',
    (tester) async {
      final rig = _PushRig();
      rig.messaging.get = () async => throw StateError('getToken offline');
      await tester.pumpWidget(rig.app());
      await rig.initialize();
      await flush(tester);
      rig.foreground.add(
        const RemoteMessage(
          data: {'type': 'driver_approaching_pickup', 'orderId': 'order-123'},
        ),
      );
      await flush(tester);
      expect(find.textContaining(driverApproachingPickupTitle), findsOneWidget);
      rig.messaging.get = () async => 'token-123456';
      await tester.pump(const Duration(seconds: 30));
      await flush(tester);
      expect(rig.api.registrations, ['passenger:token-123456']);
      rig.dispose();
    },
  );

  testWidgets('foreground message waits for messenger instead of being lost', (
    tester,
  ) async {
    final rig = _PushRig();
    await rig.initialize();
    rig.foreground.add(
      const RemoteMessage(
        data: {'type': 'driver_approaching_pickup', 'orderId': 'order-123'},
      ),
    );
    await flush(tester);
    await tester.pumpWidget(rig.app());
    await tester.pump(const Duration(milliseconds: 250));
    await flush(tester);
    expect(find.textContaining(driverApproachingPickupTitle), findsOneWidget);
    rig.dispose();
  });

  testWidgets(
    'refresh rebinds token and dispose removes all message listeners',
    (tester) async {
      final rig = _PushRig();
      var token = 'first-token-123456';
      rig.messaging.get = () async => token;
      await tester.pumpWidget(rig.app());
      await rig.initialize();
      await flush(tester);
      token = 'new-token-654321';
      rig.messaging.refresh.add(token);
      await flush(tester);
      expect(rig.api.registrations, [
        'passenger:first-token-123456',
        'passenger:new-token-654321',
      ]);
      // SDK cancellation futures complete outside the widget fake clock.
      await tester.runAsync(rig.service.dispose);
      expect(rig.foreground.hasListener, isFalse);
      expect(rig.opened.hasListener, isFalse);
      expect(rig.messaging.refresh.hasListener, isFalse);
      rig.foreground.add(
        const RemoteMessage(
          data: {'type': 'driver_approaching_pickup', 'orderId': 'order-123'},
        ),
      );
      await flush(tester);
      expect(find.textContaining(driverApproachingPickupTitle), findsNothing);
      rig.dispose();
    },
  );

  testWidgets(
    'missing order id and signed-out approaching are explicitly skipped',
    (tester) async {
      final rig = _PushRig();
      await tester.pumpWidget(rig.app());
      await rig.initialize();
      rig.foreground.add(
        const RemoteMessage(data: {'type': 'driver_approaching_pickup'}),
      );
      await flush(tester);
      expect(find.textContaining(driverApproachingPickupTitle), findsNothing);
      rig.owner = null;
      rig.foreground.add(
        const RemoteMessage(
          data: {'type': 'driver_approaching_pickup', 'orderId': 'order-123'},
        ),
      );
      await flush(tester);
      expect(find.textContaining(driverApproachingPickupTitle), findsNothing);
      rig.dispose();
    },
  );

  test('Android permission and high importance default channel match', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/kz/tulpar/taxi/MainActivity.kt',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_channel_id'),
    );
    expect(manifest, contains('android:value="tulpar_orders"'));
    expect(activity, contains('"tulpar_orders"'));
    expect(activity, contains('NotificationManager.IMPORTANCE_HIGH'));
    final server = File('backend/src/server.js').readAsStringSync();
    expect(server, contains("channelId: 'tulpar_orders'"));
    expect(server, contains('notification: {'));
  });

  test(
    'optional push startup has no fixed six second delay and retains timing logs',
    () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, isNot(contains('Duration(seconds: 6)')));
      expect(main, contains('registerFirebaseMessagingBackgroundHandler();'));
      expect(
        main,
        contains(
          'unawaited(_initializeDeferredServices(requiredInitialization))',
        ),
      );
      expect(main, contains("StartupDiagnostics.mark('first Flutter frame')"));
      expect(
        main,
        contains("StartupDiagnostics.mark('push notifications initialized')"),
      );
    },
  );
}

class _PushRig {
  final audio = _Audio();
  final navigator = GlobalKey<NavigatorState>();
  final messenger = GlobalKey<ScaffoldMessengerState>();
  final messaging = _Messaging();
  final api = _Api();
  int foregroundSubscriptions = 0;
  int backgroundRegistrations = 0;
  String? owner = 'passenger';
  String? savedOwner;
  late final foreground = StreamController<RemoteMessage>.broadcast(
    onListen: () {
      foregroundSubscriptions++;
    },
  );
  final opened = StreamController<RemoteMessage>.broadcast();
  late final service = PushNotificationService(
    approachingAudio: audio,
    messaging: messaging,
    auth: _Auth(),
    apiClient: api,
    foregroundMessages: foreground.stream,
    openedMessages: opened.stream,
    backgroundRegistrar: () {
      backgroundRegistrations++;
    },
    tokenOwnerId: () => owner,
    readTokenOwner: () async => savedOwner,
    writeTokenOwner: (value) async {
      savedOwner = value;
    },
  );
  Future<void> initialize() =>
      service.initialize(navigatorKey: navigator, messengerKey: messenger);
  Widget app({Locale locale = const Locale('ru')}) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    navigatorKey: navigator,
    scaffoldMessengerKey: messenger,
    home: const Scaffold(body: Text('passenger')),
  );
  void dispose() {
    unawaited(service.dispose());
    if (!messaging.permission.isCompleted) {
      messaging.permission.completeError(
        StateError('permission unavailable in test'),
      );
    }
    if (!messaging.token.isCompleted) {
      messaging.token.complete('test-device-token-123456');
    }
    api.close();
  }
}

class _Audio implements NavigationAudioOutput {
  int calls = 0;
  final cues = <NavigationAudioCue>[];
  @override
  Future<void> play(NavigationAudioCue cue) async {
    calls++;
    cues.add(cue);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _Messaging implements FirebaseMessaging {
  final token = Completer<String?>();
  final permission = Completer<NotificationSettings>();
  final refresh = StreamController<String>.broadcast();
  Future<String?> Function()? get;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) => get?.call() ?? token.future;
  @override
  Future<void> deleteToken() async {}
  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #requestPermission) return permission.future;
    return super.noSuchMethod(invocation);
  }
}

class _Auth implements FirebaseAuth {
  @override
  User? get currentUser => null;
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api extends TulparApiClient {
  final registrations = <String>[];
  @override
  Future<void> registerPushToken({
    required String token,
    String platform = 'android',
    String? expectedUserId,
  }) async {
    registrations.add('$expectedUserId:$token');
  }
}
