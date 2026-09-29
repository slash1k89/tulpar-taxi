import 'dart:async';

import 'navigation_audio_service.dart';
import 'navigation_voice_service.dart';

class ChatNotificationService {
  ChatNotificationService({NavigationAudioOutput? audio})
    : _audio =
          audio ??
          NavigationAudioService(
            fallbackSpeaker: SystemNavigationVoiceSpeaker(),
          );

  final NavigationAudioOutput _audio;
  final Set<String> _openOrders = {};
  final Set<String> _processedMessageIds = {};
  final Map<String, DateTime> _recentPushes = {};

  void openChat(String orderId) => _openOrders.add(orderId);
  void closeChat(String orderId) => _openOrders.remove(orderId);
  bool isChatOpen(String orderId) => _openOrders.contains(orderId);

  bool handlePush({required String orderId, required String messageId}) {
    if (_openOrders.contains(orderId)) return false;
    final key = '$orderId:$messageId';
    if (!_processedMessageIds.add(key)) return false;
    if (_processedMessageIds.length > 256) {
      _processedMessageIds.remove(_processedMessageIds.first);
    }
    _recentPushes[orderId] = DateTime.now();
    unawaited(_play());
    return true;
  }

  bool handlePollingIncrease({
    required String orderId,
    required int previousCount,
    required int newCount,
  }) {
    if (newCount <= previousCount || _openOrders.contains(orderId)) {
      return false;
    }
    final pushedAt = _recentPushes[orderId];
    if (pushedAt != null &&
        DateTime.now().difference(pushedAt) < const Duration(seconds: 10)) {
      return false;
    }
    if (pushedAt != null) _recentPushes.remove(orderId);
    unawaited(_play());
    return true;
  }

  Future<void> _play() => _audio.play(
    const NavigationAudioCue(
      assetPaths: ['audio/navigation/message_new.mp3'],
      fallbackText: 'Новое сообщение',
    ),
  );
}

final chatNotificationService = ChatNotificationService();
