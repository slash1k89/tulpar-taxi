import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'voice_asset_service.dart';

abstract interface class NavigationFallbackSpeaker {
  Future<void> speak(String text);
  Future<void> stop();
}

abstract interface class NavigationAssetPlayer {
  Future<void> playAsset(String assetPath);
  Future<void> stop();
  Future<void> dispose();
}

abstract interface class NavigationAudioOutput {
  Future<void> play(NavigationAudioCue cue);
  Future<void> stop();
  Future<void> dispose();
}

class NavigationAudioCue {
  const NavigationAudioCue({
    this.assetPaths = const [],
    required this.fallbackText,
  });

  final List<String> assetPaths;
  final String fallbackText;
}

class AudioplayersNavigationAssetPlayer implements NavigationAssetPlayer {
  AudioplayersNavigationAssetPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  Completer<void>? _activeCompletion;
  StreamSubscription<void>? _activeCompletionSubscription;
  bool _disposed = false;

  @override
  Future<void> playAsset(String assetPath) async {
    if (_disposed) return;

    final completion = Completer<void>();
    late final StreamSubscription<void> completionSubscription;
    completionSubscription = _player.onPlayerComplete.listen((_) {
      if (!completion.isCompleted) completion.complete();
    });
    _activeCompletion = completion;
    _activeCompletionSubscription = completionSubscription;

    try {
      await _player.play(AssetSource(assetPath));
      await completion.future;
    } finally {
      await completionSubscription.cancel();
      if (identical(_activeCompletion, completion)) {
        _activeCompletion = null;
        _activeCompletionSubscription = null;
      }
    }
  }

  @override
  Future<void> stop() async {
    final completion = _activeCompletion;
    if (completion != null && !completion.isCompleted) completion.complete();
    await _activeCompletionSubscription?.cancel();
    _activeCompletion = null;
    _activeCompletionSubscription = null;
    if (!_disposed) {
      try {
        await _player.stop();
      } catch (_) {
        // Audio is optional and must never interrupt visual navigation.
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    try {
      await _player.dispose();
    } catch (_) {
      // A platform player may already have been released.
    }
  }
}

class NavigationAudioService implements NavigationAudioOutput {
  NavigationAudioService({
    NavigationAssetPlayer? assetPlayer,
    required NavigationFallbackSpeaker fallbackSpeaker,
    String Function(String assetPath)? assetPathResolver,
  }) : _assetPlayer = assetPlayer ?? AudioplayersNavigationAssetPlayer(),
       _fallbackSpeaker = fallbackSpeaker,
       _assetPathResolver = assetPathResolver ?? localizedVoiceAssetPath;

  final NavigationAssetPlayer _assetPlayer;
  final NavigationFallbackSpeaker _fallbackSpeaker;
  final String Function(String assetPath) _assetPathResolver;
  int _commandGeneration = 0;
  bool _disposed = false;

  @override
  Future<void> play(NavigationAudioCue cue) async {
    if (_disposed) return;
    final generation = ++_commandGeneration;
    await _assetPlayer.stop();
    await _fallbackSpeaker.stop();
    if (_disposed || generation != _commandGeneration) return;

    if (cue.assetPaths.isEmpty) {
      await _fallbackSpeaker.speak(cue.fallbackText);
      return;
    }

    try {
      for (final assetPath in cue.assetPaths) {
        if (_disposed || generation != _commandGeneration) return;
        await _assetPlayer.playAsset(_assetPathResolver(assetPath));
      }
    } catch (_) {
      if (_disposed || generation != _commandGeneration) return;
      await _assetPlayer.stop();
      await _fallbackSpeaker.speak(cue.fallbackText);
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _commandGeneration++;
    await _assetPlayer.stop();
    await _fallbackSpeaker.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _commandGeneration++;
    await _assetPlayer.stop();
    await _fallbackSpeaker.stop();
    _disposed = true;
    await _assetPlayer.dispose();
  }
}
