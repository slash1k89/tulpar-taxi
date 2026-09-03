import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/navigation_step.dart';
import '../utils/navigation_instruction_formatter.dart';
import 'navigation_audio_service.dart';

abstract interface class NavigationVoiceSpeaker
    implements NavigationFallbackSpeaker {}

class SystemNavigationVoiceSpeaker implements NavigationVoiceSpeaker {
  SystemNavigationVoiceSpeaker({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _initialized = false;
  bool _available = false;

  Future<bool> _initialize() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      final available = await _tts.isLanguageAvailable('ru-RU');
      if (available != true && available != 1) return false;
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      await _tts.awaitSpeakCompletion(false);
      _available = true;
    } catch (_) {
      // Visual navigation remains available when the system TTS is missing.
    }
    return _available;
  }

  @override
  Future<void> speak(String text) async {
    try {
      if (!await _initialize()) return;
      await _tts.stop();
      await _tts.speak(text, focus: true);
    } catch (_) {
      // TTS is optional and must never interrupt navigation.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

enum NavigationVoiceStage { initial, advance, near, immediate }

class NavigationVoiceController {
  NavigationVoiceController({NavigationAudioOutput? audioOutput})
    : _audioOutput =
          audioOutput ??
          NavigationAudioService(
            fallbackSpeaker: SystemNavigationVoiceSpeaker(),
          );

  final NavigationAudioOutput _audioOutput;
  int _routeGeneration = -1;
  final Map<int, Set<NavigationVoiceStage>> _announced = {};
  bool _disposed = false;

  void replaceRoute(int routeGeneration) {
    if (_routeGeneration == routeGeneration) return;
    _routeGeneration = routeGeneration;
    _announced.clear();
    unawaited(_audioOutput.stop());
  }

  void update({
    required bool active,
    required bool enabled,
    required int stepIndex,
    required NavigationStep? step,
    required double? distanceMeters,
    bool arrivalConfirmed = true,
  }) {
    if (_disposed) return;
    if (!active || !enabled || step == null) {
      if (!active || !enabled) unawaited(_audioOutput.stop());
      return;
    }

    final type = step.type.trim().toLowerCase().replaceAll('_', ' ');
    if (type == 'arrive') {
      if (!arrivalConfirmed) {
        if (kDebugMode) {
          debugPrint(
            '[NavVoice] step=$stepIndex skipped=arrival_not_confirmed '
            'distance=$distanceMeters',
          );
        }
        return;
      }
      _announce(
        stepIndex,
        NavigationVoiceStage.immediate,
        navigationAudioCue(step, distanceMeters, immediate: true),
      );
      return;
    }
    if (distanceMeters == null ||
        !distanceMeters.isFinite ||
        distanceMeters < 0) {
      return;
    }
    final stage = switch (distanceMeters) {
      <= 40 => NavigationVoiceStage.immediate,
      <= 120 => NavigationVoiceStage.near,
      <= 350 => NavigationVoiceStage.advance,
      _ => null,
    };
    final command = navigationVoiceCommand(step);
    final stages = _announced.putIfAbsent(stepIndex, () => {});
    if (stages.isEmpty) {
      stages.add(NavigationVoiceStage.initial);
      if (stage != null) stages.add(stage);
      final distance = NavigationInstructionFormatter.formatSpokenDistance(
        distanceMeters,
      );
      final cue = navigationAudioCue(
        step,
        distanceMeters,
        immediate: stage == NavigationVoiceStage.immediate,
        fallbackText: distanceMeters < 25
            ? command
            : 'Через $distance $command',
      );
      if (kDebugMode) {
        debugPrint(
          '[NavVoice] step=$stepIndex spoken=initial text=${cue.fallbackText}',
        );
      }
      unawaited(_audioOutput.play(cue));
      return;
    }
    if (stage == null) return;
    final fallbackText = switch (stage) {
      NavigationVoiceStage.advance =>
        'Через ${NavigationInstructionFormatter.formatSpokenDistance(_roundedDistance(distanceMeters, 50).toDouble())} $command',
      NavigationVoiceStage.near =>
        'Через ${NavigationInstructionFormatter.formatSpokenDistance(_roundedDistance(distanceMeters, 10).toDouble())} $command',
      NavigationVoiceStage.immediate => command,
      NavigationVoiceStage.initial => throw StateError('Initial handled above'),
    };
    _announce(
      stepIndex,
      stage,
      navigationAudioCue(
        step,
        distanceMeters,
        immediate: stage == NavigationVoiceStage.immediate,
        fallbackText: fallbackText,
      ),
    );
  }

  void _announce(
    int stepIndex,
    NavigationVoiceStage stage,
    NavigationAudioCue cue,
  ) {
    final stages = _announced.putIfAbsent(stepIndex, () => {});
    if (!stages.add(stage)) {
      if (kDebugMode) {
        debugPrint('[NavVoice] step=$stepIndex skipped=duplicate stage=$stage');
      }
      return;
    }
    if (kDebugMode) {
      debugPrint(
        '[NavVoice] step=$stepIndex spoken stage=$stage text=${cue.fallbackText}',
      );
    }
    unawaited(_audioOutput.play(cue));
  }

  Future<void> dispose() async {
    _disposed = true;
    _announced.clear();
    await _audioOutput.dispose();
  }
}

const _navigationAudioPrefix = 'audio/navigation';

NavigationAudioCue navigationAudioCue(
  NavigationStep step,
  double? distanceMeters, {
  required bool immediate,
  String? fallbackText,
}) {
  final command = navigationVoiceCommand(step);
  final safeFallback = fallbackText ?? command;
  final type = _normalizeManeuver(step.type);
  final modifier = _normalizeManeuver(step.modifier);

  if (type == 'arrive') {
    return const NavigationAudioCue(
      assetPaths: ['$_navigationAudioPrefix/route_finish.mp3'],
      fallbackText: 'Вы прибыли в точку назначения.',
    );
  }

  final maneuverAssets = _maneuverAssets(
    type: type,
    modifier: modifier,
    exitNumber: step.exitNumber,
  );
  if (maneuverAssets == null) {
    return NavigationAudioCue(fallbackText: safeFallback);
  }

  final assets = <String>[];
  if (!immediate && distanceMeters != null) {
    final distanceAsset = navigationDistanceAsset(distanceMeters);
    if (distanceAsset != null) assets.add(distanceAsset);
  }
  assets.addAll(maneuverAssets);
  return NavigationAudioCue(assetPaths: assets, fallbackText: safeFallback);
}

String? navigationDistanceAsset(double meters) {
  if (!meters.isFinite || meters < 100) return null;
  const thresholds = <(double, String)>[
    (3000, 'dist_3km.mp3'),
    (2000, 'dist_2km.mp3'),
    (1000, 'dist_1km.mp3'),
    (800, 'dist_800m.mp3'),
    (500, 'dist_500m.mp3'),
    (300, 'dist_300m.mp3'),
    (200, 'dist_200m.mp3'),
    (100, 'dist_100m.mp3'),
  ];
  for (final (threshold, fileName) in thresholds) {
    if (meters >= threshold) return '$_navigationAudioPrefix/$fileName';
  }
  return null;
}

List<String>? _maneuverAssets({
  required String type,
  required String modifier,
  required int? exitNumber,
}) {
  if (_isRoundabout(type)) {
    if (exitNumber == null) {
      return const ['$_navigationAudioPrefix/roundabout_enter.mp3'];
    }
    if (exitNumber < 1 || exitNumber > 4) return null;
    return [
      '$_navigationAudioPrefix/roundabout_enter.mp3',
      '$_navigationAudioPrefix/roundabout_exit_$exitNumber.mp3',
    ];
  }
  if (type == 'exit roundabout' || type == 'exit rotary') return null;
  if (type == 'uturn' || modifier == 'uturn') {
    return const ['$_navigationAudioPrefix/turn_around.mp3'];
  }
  if (type == 'depart' ||
      type == 'merge' ||
      type == 'on ramp' ||
      type == 'onramp' ||
      type == 'off ramp' ||
      type == 'offramp') {
    return null;
  }
  if (type == 'continue' || type == 'new name') {
    return const ['$_navigationAudioPrefix/turn_straight.mp3'];
  }
  if (type == 'fork') {
    if (_isLeft(modifier)) {
      return const ['$_navigationAudioPrefix/turn_keep_left.mp3'];
    }
    if (_isRight(modifier)) {
      return const ['$_navigationAudioPrefix/turn_keep_right.mp3'];
    }
    return const ['$_navigationAudioPrefix/turn_straight.mp3'];
  }
  if (type != 'turn' && type != 'end of road') return null;
  if (modifier == 'slight left' || modifier == 'keep left') {
    return const ['$_navigationAudioPrefix/turn_keep_left.mp3'];
  }
  if (modifier == 'slight right' || modifier == 'keep right') {
    return const ['$_navigationAudioPrefix/turn_keep_right.mp3'];
  }
  if (modifier == 'left' || modifier == 'sharp left') {
    return const ['$_navigationAudioPrefix/turn_left.mp3'];
  }
  if (modifier == 'right' || modifier == 'sharp right') {
    return const ['$_navigationAudioPrefix/turn_right.mp3'];
  }
  if (modifier == 'straight') {
    return const ['$_navigationAudioPrefix/turn_straight.mp3'];
  }
  return null;
}

bool _isRoundabout(String type) =>
    type == 'roundabout' || type == 'rotary' || type == 'roundabout turn';

bool _isLeft(String modifier) => modifier.contains('left');

bool _isRight(String modifier) => modifier.contains('right');

String _normalizeManeuver(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('_', ' ')
    .replaceAll('-', ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

String navigationVoiceCommand(NavigationStep step) {
  final type = step.type.trim().toLowerCase().replaceAll('_', ' ');
  if ((type == 'roundabout' || type == 'rotary' || type == 'roundabout turn') &&
      step.exitNumber != null) {
    return 'на круговом движении воспользуйтесь '
        '${_ordinalExit(step.exitNumber!)} съездом.';
  }
  final instruction = NavigationInstructionFormatter.format(step).instruction;
  return '${instruction[0].toLowerCase()}${instruction.substring(1)}.';
}

int _roundedDistance(double meters, int step) {
  final rounded = (meters / step).round() * step;
  return rounded < step ? step : rounded;
}

String _ordinalExit(int exit) => switch (exit) {
  1 => 'первым',
  2 => 'вторым',
  3 => 'третьим',
  4 => 'четвёртым',
  5 => 'пятым',
  6 => 'шестым',
  7 => 'седьмым',
  8 => 'восьмым',
  9 => 'девятым',
  10 => 'десятым',
  _ => '$exit-м',
};
