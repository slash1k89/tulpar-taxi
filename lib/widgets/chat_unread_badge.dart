import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tulpar_api_client.dart';
import '../services/chat_notification_service.dart';

class ChatUnreadBadge extends StatefulWidget {
  const ChatUnreadBadge({
    super.key,
    required this.orderId,
    this.apiClient,
    this.intercity = false,
  });

  final String orderId;
  final TulparApiClient? apiClient;
  final bool intercity;

  static String labelFor(int count) => count > 99 ? '99+' : '$count';
  static final ValueNotifier<String?> refreshSignal = ValueNotifier(null);
  static final ValueNotifier<int> readRevision = ValueNotifier(0);
  static final Map<String, int> _readRevisions = {};
  static String _key(String orderId, bool intercity) =>
      '${intercity ? 'intercity' : 'city'}:$orderId';
  static void markReadConfirmed(String orderId, {bool intercity = false}) {
    _readRevisions[_key(orderId, intercity)] = readRevision.value + 1;
    if (_readRevisions.length > 256) {
      _readRevisions.remove(_readRevisions.keys.first);
    }
    readRevision.value++;
  }

  static void refreshOrder(String orderId) {
    refreshSignal.value = null;
    refreshSignal.value = orderId;
  }

  @override
  State<ChatUnreadBadge> createState() => _ChatUnreadBadgeState();
}

class _ChatUnreadBadgeState extends State<ChatUnreadBadge>
    with WidgetsBindingObserver {
  late final TulparApiClient _api = widget.apiClient ?? TulparApiClient();
  Timer? _timer;
  int _count = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatUnreadBadge.refreshSignal.addListener(_onRefreshSignal);
    ChatUnreadBadge.readRevision.addListener(_onReadRevision);
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  void _onRefreshSignal() {
    if (ChatUnreadBadge.refreshSignal.value == widget.orderId) {
      unawaited(_load());
    }
  }

  void _onReadRevision() {
    if (ChatUnreadBadge._readRevisions[ChatUnreadBadge._key(
          widget.orderId,
          widget.intercity,
        )] !=
        ChatUnreadBadge.readRevision.value) {
      return;
    }
    if (mounted && _count != 0) setState(() => _count = 0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    if (chatNotificationService.isChatOpen(widget.orderId)) return;
    final revision = ChatUnreadBadge
        ._readRevisions[ChatUnreadBadge._key(widget.orderId, widget.intercity)];
    try {
      final count = widget.intercity
          ? await _api.getIntercityChatUnreadCount(widget.orderId)
          : await _api.getChatUnreadCount(widget.orderId);
      if (!mounted ||
          chatNotificationService.isChatOpen(widget.orderId) ||
          revision !=
              ChatUnreadBadge._readRevisions[ChatUnreadBadge._key(
                widget.orderId,
                widget.intercity,
              )]) {
        return;
      }
      if (_initialized) {
        chatNotificationService.handlePollingIncrease(
          orderId: widget.orderId,
          previousCount: _count,
          newCount: count,
        );
      }
      _initialized = true;
      if (count != _count) setState(() => _count = count);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ChatUnreadBadge.refreshSignal.removeListener(_onRefreshSignal);
    ChatUnreadBadge.readRevision.removeListener(_onReadRevision);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      const Icon(Icons.chat),
      if (_count > 0)
        Positioned(
          right: -10,
          top: -10,
          child: Container(
            key: const Key('chat_unread_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ChatUnreadBadge.labelFor(_count),
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
    ],
  );
}
