import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/push_token_registration.dart';

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(Duration.zero);
  }
}

void main() {
  testWidgets(
    'getToken failure retries automatically; success binds current Tulpar user',
    (tester) async {
      final rig = _Rig();
      var attempts = 0;
      rig.get = () async {
        if (++attempts == 1) throw StateError('offline');
        return 'device-token-123456';
      };
      unawaited(rig.sync.sync());
      await flush(tester);
      expect(rig.registrations, isEmpty);
      await tester.pump(const Duration(seconds: 30));
      await flush(tester);
      expect(rig.registrations, ['user-a:device-token-123456']);
      rig.sync.dispose();
    },
  );

  testWidgets(
    'backend registration failure retries; same token does not duplicate',
    (tester) async {
      final rig = _Rig();
      var attempts = 0;
      rig.send = (_, _) async {
        if (++attempts == 1) throw StateError('offline');
      };
      unawaited(rig.sync.sync());
      await flush(tester);
      await tester.pump(const Duration(seconds: 30));
      await flush(tester);
      expect(attempts, 2);
      unawaited(rig.sync.sync());
      await flush(tester);
      expect(attempts, 2);
      rig.token = 'refreshed-token-654321';
      unawaited(rig.sync.sync());
      await flush(tester);
      expect(attempts, 3);
      rig.sync.dispose();
    },
  );

  testWidgets(
    'logout invalidates token; next login registers for new account',
    (tester) async {
      final rig = _Rig();
      unawaited(rig.sync.sync());
      await flush(tester);
      rig.user = null;
      unawaited(rig.sync.sync());
      await flush(tester);
      expect(rig.deleted, 1);
      expect(rig.savedOwner, isNull);
      rig.user = 'user-b';
      unawaited(rig.sync.sync());
      await flush(tester);
      expect(rig.savedOwner, 'user-b');
      expect(rig.registrations.last, startsWith('user-b:'));
      rig.sync.dispose();
    },
  );

  testWidgets(
    'persisted previous account is invalidated after process restart',
    (tester) async {
      final rig = _Rig()..savedOwner = 'previous-user';
      unawaited(rig.sync.sync());
      await flush(tester);
      expect(rig.deleted, 1);
      expect(rig.savedOwner, 'user-a');
      expect(rig.registrations, hasLength(1));
      rig.sync.dispose();
    },
  );

  testWidgets('account switches during getToken never register stale owner', (
    tester,
  ) async {
    final rig = _Rig();
    final pending = Completer<String?>();
    rig.get = () => pending.future;
    unawaited(rig.sync.sync());
    await flush(tester);
    rig.user = 'user-b';
    rig.get = null;
    unawaited(rig.sync.sync());
    pending.complete('old-device-token');
    await flush(tester);
    expect(rig.deleted, 1);
    expect(rig.registrations, ['user-b:device-token-123456']);
    rig.sync.dispose();
  });

  testWidgets(
    'account switch during HTTP registration is serialized and rebound',
    (tester) async {
      final rig = _Rig();
      final pending = Completer<void>();
      var inFlight = 0;
      var maximum = 0;
      rig.send = (_, owner) async {
        inFlight++;
        if (inFlight > maximum) maximum = inFlight;
        if (owner == 'user-a') await pending.future;
        inFlight--;
      };
      unawaited(rig.sync.sync());
      await flush(tester);
      rig.user = 'user-b';
      unawaited(rig.sync.sync());
      pending.complete();
      await flush(tester);
      expect(maximum, 1);
      expect(rig.deleted, 1);
      expect(rig.registrations.last, startsWith('user-b:'));
      expect(rig.savedOwner, 'user-b');
      rig.sync.dispose();
    },
  );

  testWidgets('logout during failed getToken still invalidates old device', (
    tester,
  ) async {
    final rig = _Rig();
    final pending = Completer<String?>();
    rig.get = () => pending.future;
    unawaited(rig.sync.sync());
    await flush(tester);
    rig.user = null;
    unawaited(rig.sync.sync());
    pending.completeError(StateError('token failure'));
    await flush(tester);
    expect(rig.deleted, 1);
    expect(rig.registrations, isEmpty);
    expect(rig.savedOwner, isNull);
    rig.sync.dispose();
  });

  testWidgets('dispose cancels retry and ignores pending result', (
    tester,
  ) async {
    final rig = _Rig();
    var attempts = 0;
    rig.get = () async {
      attempts++;
      return null;
    };
    unawaited(rig.sync.sync());
    await flush(tester);
    rig.sync.dispose();
    await tester.pump(const Duration(seconds: 60));
    expect(attempts, 1);
    expect(rig.registrations, isEmpty);
  });

  testWidgets('dispose ignores a token obtained after disposal', (
    tester,
  ) async {
    final rig = _Rig();
    final pending = Completer<String?>();
    rig.get = () => pending.future;
    unawaited(rig.sync.sync());
    await flush(tester);
    rig.sync.dispose();
    pending.complete('late-device-token-123456');
    await flush(tester);
    expect(rig.registrations, isEmpty);
  });

  test('diagnostic token suffix never contains full token', () {
    expect(pushTokenSuffix('secret-fcm-token-123456'), '123456');
    expect(pushTokenSuffix('short'), '<short-token>');
  });
}

class _Rig {
  String? user = 'user-a';
  String? savedOwner;
  String token = 'device-token-123456';
  int deleted = 0;
  final registrations = <String>[];
  Future<String?> Function()? get;
  Future<void> Function(String, String)? send;
  late final sync = PushTokenRegistration(
    currentUserId: () => user,
    getToken: () => get?.call() ?? Future.value(token),
    deleteToken: () async {
      deleted++;
    },
    readOwner: () async => savedOwner,
    writeOwner: (owner) async {
      savedOwner = owner;
    },
    register: (token, owner) async {
      registrations.add('$owner:$token');
      await send?.call(token, owner);
    },
  );
}
