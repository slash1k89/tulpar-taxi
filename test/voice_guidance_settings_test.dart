import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/voice_guidance_settings.dart';

void main() {
  test('voice defaults to on and persists user choice', () async {
    final store = _Store();
    final settings = VoiceGuidanceSettings(store: store);

    await settings.load();
    expect(settings.enabled, isTrue);

    await settings.setEnabled(false);
    expect(settings.enabled, isFalse);
    expect(store.value, isFalse);
  });
}

class _Store implements VoiceGuidancePreferenceStore {
  bool? value;

  @override
  Future<bool?> read() async => value;

  @override
  Future<void> write(bool enabled) async => value = enabled;
}
