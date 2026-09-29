import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/services/locale_controller.dart';
import 'package:taxi_esil/services/navigation_audio_service.dart';
import 'package:taxi_esil/services/voice_asset_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ru, kk, en and unknown locale resolve the expected voice folder', () {
    for (final file in const [
      'order_new.mp3',
      'message_new.mp3',
      'order_cancelled.mp3',
      'turn_left.mp3',
      'turn_right.mp3',
      'dist_50m.mp3',
      'dist_1km.mp3',
      'roundabout_exit_3.mp3',
    ]) {
      expect(voiceAsset(file, languageCode: 'ru'), 'audio/navigation/ru/$file');
      expect(voiceAsset(file, languageCode: 'kk'), 'audio/navigation/kk/$file');
      expect(voiceAsset(file, languageCode: 'en'), 'audio/navigation/en/$file');
      expect(voiceAsset(file, languageCode: 'de'), 'audio/navigation/ru/$file');
    }
  });

  test('formerly missing recordings use their localized files', () {
    expect(
      voiceAsset('dist_2km.mp3', languageCode: 'kk'),
      'audio/navigation/kk/dist_2km.mp3',
    );
    expect(
      voiceAsset('driver_approaching.mp3', languageCode: 'en'),
      'audio/navigation/en/driver_approaching.mp3',
    );
    expect(
      voiceAsset('driver_approaching.mp3', languageCode: 'kk'),
      'audio/navigation/kk/driver_approaching.mp3',
    );
  });

  test(
    'every logical cue resolves to a bundled MP3 for every locale',
    () async {
      for (final language in const ['ru', 'kk', 'en', 'unknown']) {
        for (final file in voiceAssetFileNames) {
          final path = voiceAsset(file, languageCode: language);
          final data = await rootBundle.load('assets/$path');
          expect(data.lengthInBytes, greaterThan(0), reason: '$language $file');
        }
      }
    },
  );

  test('changing the selected locale changes the next played asset', () async {
    SharedPreferences.setMockInitialValues({});
    await appLocaleController.load();
    final player = _RecordingPlayer();
    final service = NavigationAudioService(
      assetPlayer: player,
      fallbackSpeaker: _SilentSpeaker(),
    );
    const cue = NavigationAudioCue(
      assetPaths: ['audio/navigation/turn_left.mp3'],
      fallbackText: 'turn',
    );

    await appLocaleController.choose('ru');
    await service.play(cue);
    await appLocaleController.choose('kk');
    await service.play(cue);
    await appLocaleController.choose('en');
    await service.play(cue);

    expect(player.played, [
      'audio/navigation/ru/turn_left.mp3',
      'audio/navigation/kk/turn_left.mp3',
      'audio/navigation/en/turn_left.mp3',
    ]);
    await service.dispose();
  });
}

class _RecordingPlayer implements NavigationAssetPlayer {
  final played = <String>[];

  @override
  Future<void> playAsset(String assetPath) async => played.add(assetPath);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _SilentSpeaker implements NavigationFallbackSpeaker {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
