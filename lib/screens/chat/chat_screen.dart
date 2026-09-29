import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

import '../../services/tulpar_api_client.dart';
import '../../services/app_identity_service.dart';
import '../../services/chat_notification_service.dart';
import '../../widgets/chat_unread_badge.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String peerName;
  final TulparApiClient? apiClient;
  final bool intercity;
  final String? peerUserId;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.peerName,
    this.apiClient,
    this.intercity = false,
    this.peerUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  late final TulparApiClient _api;

  final String _currentUserId = AppIdentityService().currentUserId ?? '';

  Timer? _refreshTimer;
  Timer? _sendRetryTimer;
  DateTime? _sendBlockedUntil;

  List<Map<String, dynamic>> _messages = const [];

  bool _isLoading = true;
  bool _isSending = false;

  Object? _error;

  String? get _peerUserId {
    if (widget.peerUserId?.isNotEmpty ?? false) return widget.peerUserId;
    for (final message in _messages) {
      final sender = message['senderId']?.toString();
      if (sender != null && sender.isNotEmpty && sender != _currentUserId) {
        return sender;
      }
    }
    return null;
  }

  Future<void> _reportPeer() async {
    final peer = _peerUserId;
    if (peer == null) return;
    final l10n = AppLocalizations.of(context);
    final choices = [
      ('abuse', l10n.reportReasonAbuse),
      ('harassment', l10n.reportReasonHarassment),
      ('spam', l10n.reportReasonSpam),
      ('unsafe_behavior', l10n.reportReasonUnsafe),
      ('inappropriate_content', l10n.reportReasonInappropriate),
      ('other', l10n.reportReasonOther),
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(AppLocalizations.of(dialogContext).reportUser),
        children: choices
            .map(
              (item) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, item.$1),
                child: Text(item.$2),
              ),
            )
            .toList(),
      ),
    );
    if (reason == null || !mounted) return;
    await _api.createContentReport(
      reportedUserId: peer,
      contextType: widget.intercity ? 'intercity_chat' : 'city_chat',
      reasonCode: reason,
      bookingId: widget.intercity ? widget.orderId : null,
      orderId: widget.intercity ? null : widget.orderId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).reportSent)),
      );
    }
  }

  Future<void> _blockPeer() async {
    final peer = _peerUserId;
    if (peer == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext).blockUser),
        content: Text(AppLocalizations.of(dialogContext).blockUserConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(dialogContext).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(dialogContext).blockUser),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _api.blockUser(peer);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).userBlocked)),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _api = widget.apiClient ?? TulparApiClient();
    chatNotificationService.openChat(widget.orderId);

    _loadMessages();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadMessages(silent: true),
    );
  }

  @override
  void dispose() {
    chatNotificationService.closeChat(widget.orderId);
    ChatUnreadBadge.refreshOrder(widget.orderId);
    _refreshTimer?.cancel();
    _sendRetryTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      final messages = widget.intercity
          ? await _api.getIntercityChatMessages(widget.orderId)
          : await _api.getChatMessages(widget.orderId);

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _error = null;

        if (!silent) {
          _isLoading = false;
        }
      });
      try {
        if (widget.intercity) {
          await _api.markIntercityChatRead(widget.orderId);
        } else {
          await _api.markChatRead(widget.orderId);
        }
        if (mounted) {
          ChatUnreadBadge.markReadConfirmed(
            widget.orderId,
            intercity: widget.intercity,
          );
        }
      } catch (error) {
        debugPrint('[Chat] mark read failed: $error');
        ChatUnreadBadge.refreshOrder(widget.orderId);
      }
    } catch (error) {
      if (!mounted) return;

      if (error is TulparApiException && error.statusCode == 429) {
        _startSendRetry(error.retryAfterSeconds ?? 1);
      }

      if (!silent) {
        setState(() {
          _isLoading = false;
          _error = error;
        });
      }

      debugPrint('[Chat] load failed: $error');
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending || _isSendRateLimited) return;

    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      if (widget.intercity) {
        await _api.sendIntercityChatMessage(
          bookingId: widget.orderId,
          text: text,
        );
      } else {
        await _api.sendChatMessage(orderId: widget.orderId, text: text);
      }

      _messageController.clear();

      await _loadMessages(silent: true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageForError(error))));

      debugPrint('[Chat] send failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _messageForError(Object error) {
    final l10n = AppLocalizations.of(context);
    if (error is TulparApiException) {
      switch (error.statusCode) {
        case 400:
          return l10n.chatInvalidLength;

        case 401:
          return l10n.chatInvalidRequest;

        case 403:
          return l10n.chatForbidden;

        case 404:
          return l10n.chatOrderNotFound;

        case 429:
          return l10n.chatRateLimited(error.retryAfterSeconds ?? 1);

        default:
          return l10n.chatSendFailed;
      }
    }

    return l10n.chatSendFailed;
  }

  void _startSendRetry(int seconds) {
    _sendRetryTimer?.cancel();
    _sendBlockedUntil = DateTime.now().add(Duration(seconds: seconds));
    setState(() {});
    _sendRetryTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) {
        setState(() => _sendBlockedUntil = null);
      }
    });
  }

  bool get _isSendRateLimited =>
      _sendBlockedUntil?.isAfter(DateTime.now()) ?? false;

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _timeText(dynamic value) {
    final date = _parseDate(value);

    if (date == null) return '';

    final hour = date.hour.toString().padLeft(2, '0');

    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.peerName),
        actions: [
          PopupMenuButton<String>(
            enabled: _peerUserId != null,
            onSelected: (value) {
              if (value == 'report') {
                unawaited(_reportPeer());
              }
              if (value == 'block') {
                unawaited(_blockPeer());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'report',
                child: Text(AppLocalizations.of(context).reportUser),
              ),
              PopupMenuItem(
                value: 'block',
                child: Text(AppLocalizations.of(context).blockUser),
              ),
            ],
          ),
        ],
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }

    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_messageForError(_error!), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadMessages,
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).chatEmpty));
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.all(12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          // VPS ??? ?????????? ?????????:
          // ORDER BY created_at DESC
          final data = _messages[index];

          final isMe = data['senderId']?.toString() == _currentUserId;

          final text = data['text']?.toString() ?? '';

          final time = _timeText(data['createdAt']);

          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isMe ? Colors.amber : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.black : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLength: 2000,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).chatMessageHint,
                  border: InputBorder.none,
                  counterText: '',
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: _isSending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Colors.amber),
              onPressed: _isSending || _isSendRateLimited ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
