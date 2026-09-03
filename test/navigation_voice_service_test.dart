import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/models/navigation_step.dart';
import 'package:taxi_esil/services/navigation_audio_service.dart';
import 'package:taxi_esil/services/navigation_voice_service.dart';

NavigationStep _step({
  String type = 'turn',
  String modifier = 'right',
  int? exit,
}) => NavigationStep(
  type: type,
  modifier: modifier,
  targetLat: 51,
  targetLng: 71,
  streetName: '',
  exitNumber: exit,
);

List<String> _assets(
  double distance,
  NavigationStep step, {
  bool immediate = false,
}) => navigationAudioCue(step, distance, immediate: immediate).assetPaths;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all supplied Silero MP3 files are bundled as Flutter assets', () async {
    const files = [
      'dist_100m.mp3',
      'dist_200m.mp3',
      'dist_300m.mp3',
      'dist_500m.mp3',
      'dist_800m.mp3',
      'dist_1km.mp3',
      'dist_2km.mp3',
      'dist_3km.mp3',
      'turn_left.mp3',
      'turn_right.mp3',
      'turn_keep_left.mp3',
      'turn_keep_right.mp3',
      'turn_straight.mp3',
      'turn_around.mp3',
      'roundabout_enter.mp3',
      'roundabout_exit_1.mp3',
      'roundabout_exit_2.mp3',
      'roundabout_exit_3.mp3',
      'roundabout_exit_4.mp3',
      'route_created.mp3',
      'route_recalculating.mp3',
      'route_finish.mp3',
      'order_new.mp3',
      'order_waiting.mp3',
      'order_arrived.mp3',
      'order_complete.mp3',
    ];

    for (final file in files) {
      final data = await rootBundle.load('assets/audio/navigation/$file');
      expect(data.lengthInBytes, greaterThan(0), reason: file);
    }
  });

  group('Silero navigation cue mapping', () {
    test('320m + right uses 300m then right', () {
      expect(_assets(320, _step()), [
        'audio/navigation/dist_300m.mp3',
        'audio/navigation/turn_right.mp3',
      ]);
    });

    test('110m + left uses 100m then left', () {
      expect(_assets(110, _step(modifier: 'left')), [
        'audio/navigation/dist_100m.mp3',
        'audio/navigation/turn_left.mp3',
      ]);
    });

    test('immediate maneuver never announces a false distance', () {
      expect(_assets(40, _step(), immediate: true), [
        'audio/navigation/turn_right.mp3',
      ]);
    });

    test('long initial distances use safe floor mapping', () {
      expect(navigationDistanceAsset(1400), 'audio/navigation/dist_1km.mp3');
      expect(navigationDistanceAsset(2600), 'audio/navigation/dist_2km.mp3');
      expect(navigationDistanceAsset(3100), 'audio/navigation/dist_3km.mp3');
      expect(navigationDistanceAsset(2600), isNot(contains('dist_3km')));
    });

    test('keep and slight turns use keep assets', () {
      for (final modifier in ['keep left', 'slight left']) {
        expect(_assets(30, _step(modifier: modifier), immediate: true), [
          'audio/navigation/turn_keep_left.mp3',
        ]);
      }
      for (final modifier in ['keep right', 'slight right']) {
        expect(_assets(30, _step(modifier: modifier), immediate: true), [
          'audio/navigation/turn_keep_right.mp3',
        ]);
      }
    });

    test('u-turn and sharp turns use safe available assets', () {
      expect(_assets(30, _step(modifier: 'uturn'), immediate: true), [
        'audio/navigation/turn_around.mp3',
      ]);
      expect(_assets(30, _step(modifier: 'sharp left'), immediate: true), [
        'audio/navigation/turn_left.mp3',
      ]);
      expect(_assets(30, _step(modifier: 'sharp right'), immediate: true), [
        'audio/navigation/turn_right.mp3',
      ]);
    });

    test('roundabout exits 1 through 4 use exact recordings', () {
      for (var exit = 1; exit <= 4; exit++) {
        expect(_assets(30, _step(type: 'roundabout', exit: exit)), [
          'audio/navigation/roundabout_enter.mp3',
          'audio/navigation/roundabout_exit_$exit.mp3',
        ]);
      }
    });

    test('unknown roundabout exit never uses a wrong exit recording', () {
      final cue = navigationAudioCue(
        _step(type: 'roundabout', exit: 5),
        300,
        immediate: false,
      );
      expect(cue.assetPaths, isEmpty);
      expect(cue.fallbackText, contains('пятым съездом'));
    });

    test('arrival uses route finish', () {
      final cue = navigationAudioCue(_step(type: 'arrive'), 0, immediate: true);
      expect(cue.assetPaths, ['audio/navigation/route_finish.mp3']);
    });
  });

  test('voice setting off prevents playback and stops stale audio', () async {
    final output = _RecordingOutput();
    final controller = NavigationVoiceController(audioOutput: output);
    controller.update(
      active: true,
      enabled: false,
      stepIndex: 0,
      step: _step(),
      distanceMeters: 30,
    );
    await Future<void>.delayed(Duration.zero);
    expect(output.cues, isEmpty);
    expect(output.stopCalls, 1);
    await controller.dispose();
  });

  test('controller keeps existing 350/120/40 stage behavior', () async {
    final output = _RecordingOutput();
    final controller = NavigationVoiceController(audioOutput: output);
    controller.replaceRoute(1);
    for (final distance in [320.0, 110.0, 40.0]) {
      controller.update(
        active: true,
        enabled: true,
        stepIndex: 0,
        step: _step(),
        distanceMeters: distance,
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(output.cues.map((cue) => cue.assetPaths), [
      ['audio/navigation/dist_300m.mp3', 'audio/navigation/turn_right.mp3'],
      ['audio/navigation/dist_100m.mp3', 'audio/navigation/turn_right.mp3'],
      ['audio/navigation/turn_right.mp3'],
    ]);
    await controller.dispose();
  });

  test('advancing to step 2 enables its own voice announcement', () async {
    final output = _RecordingOutput();
    final controller = NavigationVoiceController(audioOutput: output);
    controller.replaceRoute(1);
    controller.update(
      active: true,
      enabled: true,
      stepIndex: 0,
      step: _step(modifier: 'right'),
      distanceMeters: 200,
    );
    controller.update(
      active: true,
      enabled: true,
      stepIndex: 1,
      step: _step(modifier: 'left'),
      distanceMeters: 300,
    );
    await Future<void>.delayed(Duration.zero);
    expect(output.cues, hasLength(2));
    expect(output.cues.last.fallbackText, contains('налево'));
    await controller.dispose();
  });

  test(
    'unconfirmed arrival is silent and confirmed arrival speaks once',
    () async {
      final output = _RecordingOutput();
      final controller = NavigationVoiceController(audioOutput: output);
      controller.replaceRoute(1);
      controller.update(
        active: true,
        enabled: true,
        stepIndex: 2,
        step: _step(type: 'arrive'),
        distanceMeters: 500,
        arrivalConfirmed: false,
      );
      controller.update(
        active: true,
        enabled: true,
        stepIndex: 2,
        step: _step(type: 'arrive'),
        distanceMeters: 20,
        arrivalConfirmed: true,
      );
      controller.update(
        active: true,
        enabled: true,
        stepIndex: 2,
        step: _step(type: 'arrive'),
        distanceMeters: 10,
        arrivalConfirmed: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(output.cues, hasLength(1));
      expect(
        output.cues.single.assetPaths,
        contains('audio/navigation/route_finish.mp3'),
      );
      await controller.dispose();
    },
  );

  test('asset fragments are sequential with no overlap', () async {
    final player = _ControlledAssetPlayer();
    final speaker = _FallbackSpeaker();
    final service = NavigationAudioService(
      assetPlayer: player,
      fallbackSpeaker: speaker,
    );

    final playback = service.play(
      const NavigationAudioCue(
        assetPaths: ['distance.mp3', 'maneuver.mp3'],
        fallbackText: 'fallback',
      ),
    );
    await _waitUntil(() => player.played.length == 1);
    player.completeActive();
    await _waitUntil(() => player.played.length == 2);
    player.completeActive();
    await playback;

    expect(player.played, ['distance.mp3', 'maneuver.mp3']);
    expect(player.overlapDetected, isFalse);
    expect(speaker.spoken, isEmpty);
    await service.dispose();
  });

  test('a newer instruction cancels the stale sequence', () async {
    final player = _ControlledAssetPlayer();
    final service = NavigationAudioService(
      assetPlayer: player,
      fallbackSpeaker: _FallbackSpeaker(),
    );

    final oldPlayback = service.play(
      const NavigationAudioCue(
        assetPaths: ['old_1.mp3', 'old_2.mp3'],
        fallbackText: 'old',
      ),
    );
    await _waitUntil(() => player.played.contains('old_1.mp3'));
    final newPlayback = service.play(
      const NavigationAudioCue(assetPaths: ['new.mp3'], fallbackText: 'new'),
    );
    await _waitUntil(() => player.played.contains('new.mp3'));
    player.completeActive();
    await Future.wait([oldPlayback, newPlayback]);

    expect(player.played, ['old_1.mp3', 'new.mp3']);
    expect(player.overlapDetected, isFalse);
    await service.dispose();
  });

  test('unsupported instruction uses existing TTS fallback', () async {
    final player = _ControlledAssetPlayer();
    final speaker = _FallbackSpeaker();
    final service = NavigationAudioService(
      assetPlayer: player,
      fallbackSpeaker: speaker,
    );
    final cue = navigationAudioCue(
      _step(type: 'merge', modifier: 'right'),
      300,
      immediate: false,
    );

    await service.play(cue);

    expect(cue.assetPaths, isEmpty);
    expect(player.played, isEmpty);
    expect(speaker.spoken, [cue.fallbackText]);
    await service.dispose();
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var i = 0; i < 20 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}

class _RecordingOutput implements NavigationAudioOutput {
  final List<NavigationAudioCue> cues = [];
  int stopCalls = 0;

  @override
  Future<void> play(NavigationAudioCue cue) async => cues.add(cue);

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async {}
}

class _FallbackSpeaker implements NavigationFallbackSpeaker {
  final List<String> spoken = [];
  int stopCalls = 0;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCalls++;
}

class _ControlledAssetPlayer implements NavigationAssetPlayer {
  final List<String> played = [];
  Completer<void>? _active;
  bool _playing = false;
  bool overlapDetected = false;
  bool disposed = false;

  @override
  Future<void> playAsset(String assetPath) async {
    if (_playing) overlapDetected = true;
    _playing = true;
    played.add(assetPath);
    final completion = Completer<void>();
    _active = completion;
    await completion.future;
    if (identical(_active, completion)) {
      _active = null;
      _playing = false;
    }
  }

  void completeActive() {
    final active = _active;
    if (active != null && !active.isCompleted) active.complete();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    completeActive();
    _active = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    disposed = true;
  }
}
