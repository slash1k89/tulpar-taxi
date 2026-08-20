import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/tulpar_api_client.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String peerName;

  const ChatScreen({super.key, required this.orderId, required this.peerName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  final TulparApiClient _api = TulparApiClient();

  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Timer? _refreshTimer;

  List<Map<String, dynamic>> _messages = const [];

  bool _isLoading = true;
  bool _isSending = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadMessages();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadMessages(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      final messages = await _api.getChatMessages(widget.orderId);

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _error = null;

        if (!silent) {
          _isLoading = false;
        }
      });
    } catch (error) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _isLoading = false;
          _error = _messageForError(error);
        });
      }

      debugPrint('[Chat] load failed: $error');
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await _api.sendChatMessage(orderId: widget.orderId, text: text);

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
    if (error is TulparApiException) {
      switch (error.statusCode) {
        case 400:
          return 'Сообщение должно содержать от 1 до 2000 символов.';

        case 401:
          return 'Ошибка в данных или параметрах запроса.';

        case 403:
          return 'У вас нет доступа к этому заказу.';

        case 404:
          return 'Заказ не найден.';

        default:
          return error.message;
      }
    }

    return 'Не удалось отправить сообщение.';
  }

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
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadMessages,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(child: Text('Нет сообщений. Напишите первым!'));
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
                decoration: const InputDecoration(
                  hintText: 'Сообщение...',
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
              onPressed: _isSending ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
