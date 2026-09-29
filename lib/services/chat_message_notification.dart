import 'package:flutter/widgets.dart';

class ChatActivityTracker {
  ChatActivityTracker._();

  static final Map<String, int> _openOrders = <String, int>{};

  static bool isOpen(String orderId) => (_openOrders[orderId] ?? 0) > 0;

  static void enter(String orderId) {
    _openOrders.update(orderId, (count) => count + 1, ifAbsent: () => 1);
  }

  static void leave(String orderId) {
    final count = _openOrders[orderId] ?? 0;
    if (count <= 1) {
      _openOrders.remove(orderId);
    } else {
      _openOrders[orderId] = count - 1;
    }
  }

  @visibleForTesting
  static void reset() => _openOrders.clear();
}

class ChatMessageSoundPolicy {
  final Set<String> _seenMessageIds = <String>{};

  bool shouldPlay(
    Map<String, dynamic> data, {
    required String? currentUserId,
    DateTime? now,
  }) {
    if (data['type']?.toString() != 'chat_message') return false;

    final messageId = data['messageId']?.toString().trim() ?? '';
    final orderId = data['orderId']?.toString().trim() ?? '';
    if (messageId.isEmpty || orderId.isEmpty) return false;

    // Record suppressed events too, so a delayed duplicate cannot sound after
    // the user closes the chat.
    if (!_seenMessageIds.add(messageId)) return false;
    if (ChatActivityTracker.isOpen(orderId)) return false;

    final senderId = data['senderId']?.toString();
    if (currentUserId != null && senderId == currentUserId) return false;

    final createdAt = DateTime.tryParse(data['createdAt']?.toString() ?? '');
    final clock = now ?? DateTime.now();
    if (createdAt != null &&
        clock.difference(createdAt.toLocal()).abs() >
            const Duration(minutes: 5)) {
      return false;
    }
    return true;
  }

  void clear() => _seenMessageIds.clear();

  static String assetPathFor(Locale locale) =>
      'audio/navigation/message_new.mp3';
}
