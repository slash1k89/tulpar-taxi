import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference { system, light, dark }

abstract interface class ThemePreferenceStore {
  Future<String?> read();

  Future<void> write(String value);
}

class SharedPreferencesThemeStore implements ThemePreferenceStore {
  static const _preferenceKey = 'app_theme';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_preferenceKey);
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, value);
  }
}

class ThemeController extends ChangeNotifier {
  ThemeController({ThemePreferenceStore? store})
    : _store = store ?? SharedPreferencesThemeStore();

  final ThemePreferenceStore _store;
  AppThemePreference _preference = AppThemePreference.system;

  AppThemePreference get preference => _preference;

  ThemeMode get themeMode => switch (_preference) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  Future<void> load() async {
    final storedValue = await _store.read();
    _preference = AppThemePreference.values.firstWhere(
      (preference) => preference.name == storedValue,
      orElse: () => AppThemePreference.system,
    );
    notifyListeners();
  }

  Future<void> setPreference(AppThemePreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();
    await _store.write(preference.name);
  }
}

final appThemeController = ThemeController();
