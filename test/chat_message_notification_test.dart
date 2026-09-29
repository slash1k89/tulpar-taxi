import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/chat_message_notification.dart';

void main() {
  final createdAt = DateTime(2026, 9, 17, 10).toIso8601String();

  setUp(ChatActivityTracker.reset);
  tearDown(ChatActivityTracker.reset);

  Map<String, dynamic> message({
    String id = 'message-1',
    String sender = 'driver',
  }) => {
    'type': 'chat_message',
    'orderId': 'order-1',
    'messageId': id,
    'senderId': sender,
    'createdAt': createdAt,
  };

  test('incoming push sounds once and replay with same id is silent', () {
    final policy = ChatMessageSoundPolicy();
    final now = DateTime(2026, 9, 17, 10, 1);
    expect(
      policy.shouldPlay(message(), currentUserId: 'passenger', now: now),
      isTrue,
    );
    expect(
      policy.shouldPlay(message(), currentUserId: 'passenger', now: now),
      isFalse,
    );
  });

  test('own, old and open-chat messages are silent', () {
    final policy = ChatMessageSoundPolicy();
    final now = DateTime(2026, 9, 17, 10, 10);
    expect(
      policy.shouldPlay(
        message(id: 'own', sender: 'passenger'),
        currentUserId: 'passenger',
        now: now,
      ),
      isFalse,
    );
    expect(
      policy.shouldPlay(
        message(id: 'old'),
        currentUserId: 'passenger',
        now: now,
      ),
      isFalse,
    );
    ChatActivityTracker.enter('order-1');
    final openMessage = message(id: 'open')
      ..['createdAt'] = now.toIso8601String();
    expect(
      policy.shouldPlay(openMessage, currentUserId: 'passenger', now: now),
      isFalse,
    );
  });

  test('ru, kk and en use the bundled message sound', () {
    for (final locale in const [Locale('ru'), Locale('kk'), Locale('en')]) {
      expect(
        ChatMessageSoundPolicy.assetPathFor(locale),
        'audio/navigation/message_new.mp3',
      );
    }
  });
}
