import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tulpar_api_client.dart';
import 'tulpar_auth_session.dart';

/// A null selection means the user has never chosen a language manually.
class LocaleController extends ChangeNotifier {
  LocaleController({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
    bool Function()? isAuthenticated,
    Future<void> Function(String)? sync,
    Locale Function()? systemLocale,
  }) : _read = read ?? _readPreference,
       _write = write ?? _writePreference,
       _isAuthenticated = isAuthenticated ?? _hasSession,
       _sync = sync ?? _syncLocale,
       _systemLocale =
           systemLocale ??
           (() => WidgetsBinding.instance.platformDispatcher.locale);

  static const preferenceKey = 'selected_locale';
  static const supportedLocales = [Locale('ru'), Locale('kk'), Locale('en')];

  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  final bool Function() _isAuthenticated;
  final Future<void> Function(String) _sync;
  final Locale Function() _systemLocale;
  Locale? _manualLocale;
  bool _loaded = false;

  Locale? get manualLocale => _manualLocale;
  bool get isLoaded => _loaded;
  Locale get effectiveLocale => resolveLocale(_manualLocale ?? _systemLocale());

  static Locale resolveLocale(Locale value) => switch (value.languageCode) {
    'kk' => const Locale('kk'),
    'en' => const Locale('en'),
    _ => const Locale('ru'),
  };

  Future<void> load() async {
    final raw = await _read();
    if (raw == 'ru' || raw == 'kk' || raw == 'en') {
      _manualLocale = Locale(raw!);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> choose(String languageCode) async {
    if (!const {'ru', 'kk', 'en'}.contains(languageCode)) {
      throw ArgumentError.value(languageCode, 'languageCode');
    }
    _manualLocale = Locale(languageCode);
    notifyListeners();
    await _write(languageCode);
    await syncIfAuthenticated();
  }

  Future<void> syncIfAuthenticated() async {
    if (!_isAuthenticated()) return;
    try {
      await _sync(effectiveLocale.languageCode);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Locale] backend sync failed: ${error.runtimeType}');
      }
    }
  }

  static Future<String?> _readPreference() async =>
      (await SharedPreferences.getInstance()).getString(preferenceKey);

  static Future<void> _writePreference(String code) async {
    await (await SharedPreferences.getInstance()).setString(
      preferenceKey,
      code,
    );
  }

  static bool _hasSession() {
    if (TulparAuthController.instance.hasSession) return true;
    return Firebase.apps.isNotEmpty &&
        FirebaseAuth.instance.currentUser != null;
  }

  static Future<void> _syncLocale(String code) async {
    final api = TulparApiClient();
    try {
      await api.updateCurrentUserLocale(code);
    } finally {
      api.close();
    }
  }
}

final appLocaleController = LocaleController();
