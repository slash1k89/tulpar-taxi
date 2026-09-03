import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class VoiceGuidancePreferenceStore {
  Future<bool?> read();
  Future<void> write(bool enabled);
}

class SharedPreferencesVoiceGuidanceStore
    implements VoiceGuidancePreferenceStore {
  static const _key = 'voice_guidance_enabled';

  @override
  Future<bool?> read() async =>
      (await SharedPreferences.getInstance()).getBool(_key);

  @override
  Future<void> write(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(_key, enabled);
}

class VoiceGuidanceSettings extends ChangeNotifier {
  VoiceGuidanceSettings({VoiceGuidancePreferenceStore? store})
    : _store = store ?? SharedPreferencesVoiceGuidanceStore();

  final VoiceGuidancePreferenceStore _store;
  bool _enabled = true;
  bool _loaded = false;

  bool get enabled => _enabled;

  Future<void> load() async {
    if (_loaded) return;
    _enabled = await _store.read() ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled && _loaded) return;
    _enabled = enabled;
    _loaded = true;
    notifyListeners();
    await _store.write(enabled);
  }
}

final appVoiceGuidanceSettings = VoiceGuidanceSettings();
