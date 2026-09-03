import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  required _ProfileRepository repository,
  AppMode mode = AppMode.passenger,
}) async {
  final theme = ThemeController(store: _ThemeStore());
  await tester.pumpWidget(
    MaterialApp(
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
