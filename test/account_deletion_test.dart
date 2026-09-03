import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/app_routes.dart';
import 'package:taxi_esil/screens/profile/profile_screen.dart';
import 'package:taxi_esil/services/account_deletion_service.dart';
import 'package:taxi_esil/services/driver_agreement_service.dart';
import 'package:taxi_esil/services/theme_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/services/user_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('destructive action requires two confirmations before password', (
    tester,
  ) async {
    final controller = _FakeDeletionController();
    await _pumpProfile(tester, controller);
    expect(find.byKey(const Key('delete_account_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_account_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('account_delete_first_dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account_delete_password_dialog')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('account_delete_first_confirm')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('account_delete_second_dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account_delete_password_dialog')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('account_delete_second_confirm')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('account_delete_password_dialog')),
      findsOneWidget,
    );
    expect(controller.calls, 0);
  });

  testWidgets('cancel at first confirmation stops deletion', (tester) async {
    final controller = _FakeDeletionController();
    await _pumpProfile(tester, controller);
    await tester.tap(find.byKey(const Key('delete_account_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account_delete_first_cancel')));
    await tester.pumpAndSettle();
    expect(controller.calls, 0);
    expect(find.byKey(const Key('account_delete_second_dialog')), findsNothing);
  });

  testWidgets('cancel at second confirmation stops deletion', (tester) async {
    final controller = _FakeDeletionController();
    await _pumpProfile(tester, controller);
    await _openSecondConfirmation(tester);
    await tester.tap(find.byKey(const Key('account_delete_second_cancel')));
    await tester.pumpAndSettle();
    expect(controller.calls, 0);
  });

  testWidgets('cancel password dialog stops deletion', (tester) async {
    final controller = _FakeDeletionController();
    await _pumpProfile(tester, controller);
    await _openPasswordDialog(tester);
    await tester.tap(find.byKey(const Key('account_delete_password_cancel')));
    await tester.pumpAndSettle();
    expect(controller.calls, 0);
  });

  testWidgets('empty password is rejected before controller call', (
    tester,
  ) async {
    final controller = _FakeDeletionController();
    await _pumpProfile(tester, controller);
    await _openPasswordDialog(tester);
    await tester.tap(find.byKey(const Key('account_delete_password_confirm')));
    await tester.pump();
    expect(find.text('Введите пароль'), findsOneWidget);
    expect(controller.calls, 0);
  });

  for (final failure in const [
    AccountDeletionException('wrong_password', 'Неверный пароль.'),
    AccountDeletionException(
      'network_error',
      'Нет соединения с сетью. Попробуйте ещё раз.',
    ),
    AccountDeletionException(
      'active_order',
      'Сначала завершите или отмените текущий заказ.',
    ),
  ]) {
    testWidgets('${failure.code} keeps the profile open without success', (
      tester,
    ) async {
      final controller = _FakeDeletionController(error: failure);
      await _pumpProfile(tester, controller);
      await _submitPassword(tester, 'secret-password');
      expect(controller.calls, 1);
      expect(find.text(failure.message), findsOneWidget);
      expect(find.text('Аккаунт удалён.'), findsNothing);
      expect(find.byKey(const Key('delete_account_button')), findsOneWidget);
    });
  }

  testWidgets('success is not shown before backend future completes', (
    tester,
  ) async {
    final completer = Completer<AccountDeletionOutcome>();
    final controller = _FakeDeletionController(completer: completer);
    await _pumpProfile(tester, controller);
    await _startPasswordSubmission(tester, 'secret-password');
    expect(find.text('Аккаунт удалён.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(AccountDeletionOutcome.deleted);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_probe')), findsOneWidget);
  });

  testWidgets('pending deletion signs out UX and resets navigation safely', (
    tester,
  ) async {
    final controller = _FakeDeletionController(
      outcome: AccountDeletionOutcome.pending,
    );
    await _pumpProfile(tester, controller);
    await _submitPassword(tester, 'secret-password');
    expect(find.byKey(const Key('login_probe')), findsOneWidget);
  });

  test(
    'controller reauthenticates, refreshes token and sends empty DELETE',
    () async {
      SharedPreferences.setMockInitialValues({
        'driver_agreement_acceptance_user-1':
            '{"version":"1.0","acceptedAt":"2026-08-27T00:00:00Z"}',
      });
      final events = <String>[];
      final gateway = _FakeGateway(events);
      var pushCleared = false;
      final api = TulparApiClient(
        client: MockClient((request) async {
          events.add('delete');
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/account');
          expect(request.body, isEmpty);
          expect(request.body, isNot(contains('secret-password')));
          return http.Response('{"status":"deleted"}', 200);
        }),
        tokenProvider: () async => 'fresh-token',
      );
      final controller = DefaultAccountDeletionController(
        reauthentication: gateway,
        apiClient: api,
        agreementService: DriverAgreementService(),
        clearPushToken: () async => pushCleared = true,
      );

      final outcome = await controller.deleteWithPassword('secret-password');
      expect(outcome, AccountDeletionOutcome.deleted);
      expect(events, ['reauth', 'refresh', 'delete', 'signout']);
      expect(pushCleared, isTrue);
      expect(await DriverAgreementService().getAcceptance('user-1'), isNull);
    },
  );

  test('failed reauth never refreshes token or calls backend DELETE', () async {
    final events = <String>[];
    final gateway = _FakeGateway(
      events,
      error: const AccountDeletionException(
        'wrong_password',
        'Неверный пароль.',
      ),
    );
    var apiCalls = 0;
    final controller = DefaultAccountDeletionController(
      reauthentication: gateway,
      apiClient: TulparApiClient(
        client: MockClient((request) async {
          apiCalls++;
          return http.Response('{"status":"deleted"}', 200);
        }),
        tokenProvider: () async => 'token',
      ),
      clearPushToken: () async {},
    );

    await expectLater(
      controller.deleteWithPassword('wrong'),
      throwsA(isA<AccountDeletionException>()),
    );
    expect(events, ['reauth']);
    expect(apiCalls, 0);
  });

  test('accepted deletion runs every cleanup step despite local failures', () async {
    final events = <String>[];
    final gateway = _FakeGateway(events, signOutError: StateError('signout'));
    final controller = DefaultAccountDeletionController(
      reauthentication: gateway,
      apiClient: TulparApiClient(
        client: MockClient(
          (_) async => http.Response('{"status":"deletion_pending"}', 202),
        ),
        tokenProvider: () async => 'fresh-token',
      ),
      agreementService: _FailingAgreementService(),
      clearPushToken: () async {
        events.add('push');
        throw StateError('push');
      },
    );

    final outcome = await controller.deleteWithPassword('secret-password');
    expect(outcome, AccountDeletionOutcome.pending);
    expect(events, ['reauth', 'refresh', 'push', 'signout']);
  });

  test('ambiguous DELETE timeout keeps session and supports safe retry', () async {
    final events = <String>[];
    var pushCleared = false;
    final controller = DefaultAccountDeletionController(
      reauthentication: _FakeGateway(events),
      apiClient: TulparApiClient(
        client: MockClient((_) => Completer<http.Response>().future),
        tokenProvider: () async => 'fresh-token',
        accountDeletionTimeout: const Duration(milliseconds: 1),
      ),
      clearPushToken: () async => pushCleared = true,
    );

    await expectLater(
      controller.deleteWithPassword('secret-password'),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.code,
          'code',
          'account_deletion_result_unknown',
        ),
      ),
    );
    expect(events, ['reauth', 'refresh']);
    expect(pushCleared, false);
  });
}

Future<void> _pumpProfile(
  WidgetTester tester,
  AccountDeletionController controller,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      routes: {
        AppRoutes.login: (_) =>
            const Scaffold(body: Text('Login', key: Key('login_probe'))),
      },
      home: ProfileScreen(
        repository: _ProfileRepository(),
        themeController: ThemeController(store: _ThemeStore()),
        userId: 'user-1',
        accountDeletionController: controller,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSecondConfirmation(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('delete_account_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('account_delete_first_confirm')));
  await tester.pumpAndSettle();
}

Future<void> _openPasswordDialog(WidgetTester tester) async {
  await _openSecondConfirmation(tester);
  await tester.tap(find.byKey(const Key('account_delete_second_confirm')));
  await tester.pumpAndSettle();
}

Future<void> _startPasswordSubmission(
  WidgetTester tester,
  String password,
) async {
  await _openPasswordDialog(tester);
  await tester.enterText(
    find.byKey(const Key('account_delete_password_field')),
    password,
  );
  await tester.tap(find.byKey(const Key('account_delete_password_confirm')));
  await tester.pump();
}

Future<void> _submitPassword(WidgetTester tester, String password) async {
  await _startPasswordSubmission(tester, password);
  await tester.pumpAndSettle();
}

class _FakeDeletionController implements AccountDeletionController {
  _FakeDeletionController({
    this.outcome = AccountDeletionOutcome.deleted,
    this.error,
    this.completer,
  });

  final AccountDeletionOutcome outcome;
  final AccountDeletionException? error;
  final Completer<AccountDeletionOutcome>? completer;
  int calls = 0;

  @override
  Future<AccountDeletionOutcome> deleteWithPassword(String password) async {
    calls++;
    if (error != null) throw error!;
    return completer?.future ?? outcome;
  }
}

class _FakeGateway implements AccountReauthenticationGateway {
  _FakeGateway(this.events, {this.error, this.signOutError});
  final List<String> events;
  final AccountDeletionException? error;
  final Object? signOutError;

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<void> reauthenticate(String password) async {
    events.add('reauth');
    if (error != null) throw error!;
  }

  @override
  Future<void> forceRefreshIdToken() async => events.add('refresh');

  @override
  Future<void> signOut() async {
    events.add('signout');
    if (signOutError != null) throw signOutError!;
  }
}

class _FailingAgreementService extends DriverAgreementService {
  @override
  Future<void> clearAcceptance(String userId) async {
    throw StateError('agreement');
  }
}

class _ProfileRepository implements UserProfileRepository {
  @override
  Future<UserProfile?> load(String userId) async => const UserProfile(
    name: 'User',
    phone: '+7 700 000-00-00',
    averageRating: 5,
  );

  @override
  Future<void> update({
    required String userId,
    required String name,
    required String carModel,
  }) async {}
}

class _ThemeStore implements ThemePreferenceStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}
}
