import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/chat_notification_service.dart';
import 'package:taxi_esil/services/navigation_audio_service.dart';
import 'package:taxi_esil/services/voice_asset_service.dart';

void main() {
  test('incoming push plays once and duplicate push/poll does not', () {
    final audio = _FakeAudio();
    final service = ChatNotificationService(audio: audio);
    expect(service.handlePush(orderId: 'o1', messageId: 'm1'), isTrue);
    expect(service.handlePush(orderId: 'o1', messageId: 'm1'), isFalse);
    expect(
      service.handlePollingIncrease(
        orderId: 'o1',
        previousCount: 0,
        newCount: 1,
      ),
      isFalse,
    );
    expect(
      service.handlePollingIncrease(
        orderId: 'o1',
        previousCount: 0,
        newCount: 1,
      ),
      isFalse,
    );
    expect(audio.paths, ['audio/navigation/message_new.mp3']);
  });

  test('open chat suppresses sound and polling only reacts to increases', () {
    final audio = _FakeAudio();
    final service = ChatNotificationService(audio: audio)..openChat('o1');
    expect(service.handlePush(orderId: 'o1', messageId: 'm1'), isFalse);
    expect(
      service.handlePollingIncrease(
        orderId: 'o1',
        previousCount: 0,
        newCount: 1,
      ),
      isFalse,
    );
    service.closeChat('o1');
    expect(
      service.handlePollingIncrease(
        orderId: 'o1',
        previousCount: 1,
        newCount: 2,
      ),
      isTrue,
    );
    expect(audio.paths, ['audio/navigation/message_new.mp3']);
  });

  test('message cue resolves to the selected RU KK and EN asset', () {
    for (final language in ['ru', 'kk', 'en']) {
      expect(
        localizedVoiceAssetPath(
          'audio/navigation/message_new.mp3',
          languageCode: language,
        ),
        'audio/navigation/$language/message_new.mp3',
      );
    }
  });
}

class _FakeAudio implements NavigationAudioOutput {
  final List<String> paths = [];
  @override
  Future<void> play(NavigationAudioCue cue) async =>
      paths.addAll(cue.assetPaths);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
