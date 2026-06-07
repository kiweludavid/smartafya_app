import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.conversation,
    required this.currentUserId,
  });

  final ChatConversationDto conversation;
  final String currentUserId;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessageDto> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;
  String _lastSeenMessageId = '';

  bool get _sessionExpired =>
      widget.conversation.kind.toLowerCase() == 'session' && widget.conversation.isExpired;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pollMessages());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.fetchChatMessages(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
        if (list.isNotEmpty) _lastSeenMessageId = list.last.id;
      });
      _scrollToEnd();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Could not load messages.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load messages.';
      });
    }
  }

  Future<void> _pollMessages() async {
    try {
      final list = await _api.fetchChatMessages(widget.conversation.id);
      if (!mounted) return;
      if (list.isEmpty) return;
      final latest = list.last;
      if (latest.id != _lastSeenMessageId && _lastSeenMessageId.isNotEmpty) {
        if (latest.senderId != widget.currentUserId) {
          await NotificationService.chatMessage(
            title: widget.conversation.title,
            body: latest.body.length > 80 ? '${latest.body.substring(0, 80)}…' : latest.body,
          );
        }
        setState(() {
          _messages = list;
          _lastSeenMessageId = latest.id;
        });
        _scrollToEnd();
      } else if (list.length != _messages.length) {
        setState(() {
          _messages = list;
          if (list.isNotEmpty) _lastSeenMessageId = list.last.id;
        });
        _scrollToEnd();
      }
    } catch (_) {}
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    if (_sessionExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This session chat has closed. Book again if you need help.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await _api.sendChatMessage(widget.conversation.id, trimmed);
      _controller.clear();
      await _load();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Send failed.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Send failed.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _quickReply(String text) {
    _controller.text = text;
    _send(text);
  }

  @override
  Widget build(BuildContext context) {
    final quick = widget.conversation.kind.toLowerCase() == 'admin'
        ? const ['Payment question', 'Physical visit update', 'Thank you']
        : const ['On my way', 'Running 5 min late', 'Thank you'];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: SmartAfyaPalette.deepText,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            if (_sessionExpired)
              const Text(
                'Read-only — window closed',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SmartAfyaPalette.mutedText),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_sessionExpired)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFE8EEF4),
              child: const Text(
                'This chat was available for a limited time after your session. You can still read past messages.',
                style: TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: SmartAfyaPalette.primaryBlue))
                : _error != null
                    ? Center(child: Text(_error!, textAlign: TextAlign.center))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final m = _messages[i];
                          final mine = m.senderId == widget.currentUserId;
                          return _Bubble(message: m, mine: mine);
                        },
                      ),
          ),
          if (!_sessionExpired)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: quick
                      .map(
                        (q) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(q, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            onPressed: _sending ? null : () => _quickReply(q),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFD0DDE8)),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE4EEF7))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !_sessionExpired,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sessionExpired ? null : (_) => _send(_controller.text),
                      decoration: InputDecoration(
                        hintText: _sessionExpired ? 'Chat closed' : 'Type a message…',
                        filled: true,
                        fillColor: const Color(0xFFF2F5F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending || _sessionExpired ? null : () => _send(_controller.text),
                    style: FilledButton.styleFrom(
                      backgroundColor: SmartAfyaPalette.primaryBlue,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ChatMessageDto message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final bg = mine ? SmartAfyaPalette.primaryBlue : Colors.white;
    final fg = mine ? Colors.white : SmartAfyaPalette.deepText;
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    final time = DateTime.tryParse(message.createdAt)?.toLocal();
    final timeStr = time == null
        ? ''
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(color: fg, height: 1.35, fontWeight: FontWeight.w600),
            ),
            if (timeStr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: mine ? Colors.white.withValues(alpha: 0.85) : SmartAfyaPalette.mutedText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
