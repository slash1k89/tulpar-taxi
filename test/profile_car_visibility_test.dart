import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/screens/profile/profile_screen.dart';
import 'package:taxi_esil/services/theme_service.dart';
import 'package:taxi_esil/services/user_profile_service.dart';
import 'package:taxi_esil/widgets/app_drawer.dart';

void main() {
  testWidgets('passenger hides car field and saves without car data', (
    tester,
  ) async {
    final repository = _ProfileRepository();
    await _pumpProfile(tester, repository: repository);

    expect(find.byKey(const Key('profile_car_field')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('save_profile_button')),
      300,
      scrollable: find.descendant(
        of: find.byType(ProfileScreen),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -150));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save_profile_button')));
    await tester.pump();

    expect(repository.savedCarModel, isEmpty);
  });

  testWidgets('driver sees the existing car data', (tester) async {
    final repository = _ProfileRepository();
    await _pumpProfile(tester, repository: repository, mode: AppMode.driver);

    expect(find.byKey(const Key('profile_car_field')), findsOneWidget);
    expect(find.text('Toyota Camry'), findsOneWidget);
  });

  testWidgets('profile exposes account deletion and About links', (
    tester,
  ) async {
    await _pumpProfile(tester, repository: _ProfileRepository());
    await tester.scrollUntilVisible(
      find.byKey(const Key('about_support_link')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('about_support_link')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('delete_account_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('delete_account_button')), findsOneWidget);
  });

  for (final (code, title) in [
    ('kk', 'Профиль және баптаулар'),
    ('en', 'Profile and settings'),
  ]) {
    testWidgets('profile settings use $code', (tester) async {
      await _pumpProfile(
        tester,
        repository: _ProfileRepository(),
        locale: Locale(code),
      );
      expect(find.text(title), findsOneWidget);
    });
  }
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  required _ProfileRepository repository,
  AppMode mode = AppMode.passenger,
  Locale locale = const Locale('ru'),
}) async {
  final theme = ThemeController(store: _ThemeStore());
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(arguments: mode),
          builder: (_) => ProfileScreen(
            repository: repository,
            themeController: theme,
            userId: 'user-1',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _ProfileRepository implements UserProfileRepository {
  String? savedCarModel;

  @override
  Future<UserProfile?> load(String userId) async => const UserProfile(
    name: 'Тест',
    phone: '+77011234567',
    averageRating: 5,
    carModel: 'Toyota Camry',
  );

  @override
  Future<void> update({
    required String userId,
    required String name,
    required String carModel,
  }) async {
    savedCarModel = carModel;
  }
}

class _ThemeStore implements ThemePreferenceStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}
}
