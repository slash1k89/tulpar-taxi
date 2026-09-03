import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/driver_approaching_notification.dart';
import 'package:taxi_esil/services/push_notification_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/services/navigation_audio_service.dart';

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
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
    expect(find.textContaining(driverApproachingPickupTitle), findsOneWidget);
    rig.foreground.add(
      const RemoteMessage(data: {'type': 'chat', 'orderId': 'other'}),
    );
    await flush(tester);
    expect(rig.audio.calls, 1);
    rig.dispose();
  });

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
  });

  test(
    'optional push startup has no fixed six second delay and retains timing logs',
    () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, isNot(contains('Duration(seconds: 6)')));
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
  Widget app() => MaterialApp(
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
  @override
  Future<void> play(NavigationAudioCue cue) async {
    calls++;
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
