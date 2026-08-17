import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/main.dart';
import 'package:taxi_esil/screens/profile/profile_screen.dart';
import 'package:taxi_esil/screens/splash_screen.dart';
import 'package:taxi_esil/services/splash_startup_service.dart';
import 'package:taxi_esil/services/theme_service.dart';
import 'package:taxi_esil/services/user_profile_service.dart';
import 'package:taxi_esil/widgets/app_drawer.dart';

void main() {
  testWidgets('theme preference is saved and applied without restart', (
    tester,
  ) async {
    final store = _MemoryThemeStore('dark');
    final controller = ThemeController(store: store);
    await controller.load();

    await tester.pumpWidget(
      TaxiApp(
        themeController: controller,
        home: const Scaffold(body: Text('Theme probe')),
      ),
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.text('Theme probe'))).brightness,
      Brightness.dark,
    );

    await controller.setPreference(AppThemePreference.light);
    await tester.pump();

    expect(store.value, 'light');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.brightness, Brightness.light);
  });

  testWidgets('profile saves editable fields and keeps phone read-only', (
    tester,
  ) async {
    final repository = _FakeProfileRepository();
    final themeController = ThemeController(store: _MemoryThemeStore(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: repository,
          themeController: themeController,
          userId: 'user-1',
        ),
      ),
    );
    await tester.pump();

    final phoneField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('profile_phone_field')),
        matching: find.byType(TextField),
      ),
    );
    expect(phoneField.readOnly, isTrue);
    expect(find.text('+7 700 000-00-00'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('profile_name_field')),
      '  Новое имя  ',
    );
    await tester.tap(find.byKey(const Key('save_profile_button')));
    await tester.pump();

    expect(repository.updatedUserId, 'user-1');
    expect(repository.updatedName, 'Новое имя');
    expect(repository.updatedCarModel, 'Toyota Camry');
    expect(repository.updateCalls, 1);
  });

  testWidgets('driver mode can be changed through shared drawer', (
    tester,
  ) async {
    AppMode? selectedMode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Карта')),
          drawer: AppDrawer(
            mode: AppMode.passenger,
            userLabel: 'user@test.local',
            onModeChanged: (mode) async {
              selectedMode = mode;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer_driver_mode_switch')), findsOneWidget);

    await tester.tap(find.byKey(const Key('drawer_driver_mode_switch')));
    await tester.pumpAndSettle();

    expect(selectedMode, AppMode.driver);
  });

  testWidgets('splash requests navigation only once', (tester) async {
    var navigationCount = 0;
    final loader = Completer<SplashDestination>();

    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          initializeVideo: false,
          minimumDuration: const Duration(milliseconds: 10),
          maximumDuration: const Duration(milliseconds: 50),
          startupLoader: () => loader.future,
          timeoutFallback: () => const SplashDestination.login(),
          onNavigate: (_) => navigationCount++,
        ),
      ),
    );

    loader.complete(const SplashDestination.login());
    await tester.pump(const Duration(milliseconds: 15));
    expect(navigationCount, 1);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(navigationCount, 1);
  });
}

class _MemoryThemeStore implements ThemePreferenceStore {
  _MemoryThemeStore(this.value);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class _FakeProfileRepository implements UserProfileRepository {
  String? updatedUserId;
  String? updatedName;
  String? updatedCarModel;
  int updateCalls = 0;

  @override
  Future<UserProfile?> load(String userId) async {
    return const UserProfile(
      name: 'Старое имя',
      phone: '+7 700 000-00-00',
      averageRating: 4.8,
      carModel: 'Toyota Camry',
    );
  }

  @override
  Future<void> update({
    required String userId,
    required String name,
    required String carModel,
  }) async {
    updatedUserId = userId;
    updatedName = name;
    updatedCarModel = carModel;
    updateCalls++;
  }
}
