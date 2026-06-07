import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';
import 'chat_thread_screen.dart';

/// Inbox: admin coordination + session (doctor) threads. Minimal healthcare styling.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<ChatConversationDto> _items = [];
  String? _userId;
  CurrentUserDto? _me;
  Timer? _poll;
  String _lastFingerprint = '';
  bool _readyForNotify = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 14), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String _fingerprint(List<ChatConversationDto> list) {
    return list.map((e) => '${e.id}|${e.lastMessageAt ?? ""}|${e.lastMessagePreview ?? ""}').join('~');
  }

  Future<void> _silentRefresh() async {
    try {
      final user = await _api.fetchCurrentUser();
      final list = await _api.fetchChatConversations();
      if (!mounted) return;
      final fp = _fingerprint(list);
      if (_readyForNotify && fp != _lastFingerprint && _lastFingerprint.isNotEmpty) {
        await NotificationService.chatMessage(
          title: 'New message',
          body: 'You have new activity in Smart Afya chat.',
        );
      }
      setState(() {
        _me = user;
        _userId = user.id;
        _items = list;
        _lastFingerprint = fp;
        _readyForNotify = true;
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _api.fetchCurrentUser();
      final list = await _api.fetchChatConversations();
      if (!mounted) return;
      setState(() {
        _me = user;
        _userId = user.id;
        _items = list;
        _lastFingerprint = _fingerprint(list);
        _readyForNotify = false;
        _loading = false;
      });
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _readyForNotify = true);
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Could not load chats.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load chats.';
      });
    }
  }

  String get _emptyHint {
    final r = (_me?.role ?? '').toLowerCase();
    if (r == 'admin') {
      return 'No client threads yet.\nWhen clients open coordination chat, they appear here.';
    }
    if (r == 'doctor') {
      return 'No session chats yet.\nThreads open when you are assigned to a client session.';
    }
    return 'No conversations yet.\nAfter you book, use Session chats with your specialist and Admin for payments & visits.';
  }

  static String _formatTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (now.difference(dt).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[(dt.weekday - 1).clamp(0, 6)];
    }
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final adminChats = _items.where((c) => c.kind.toLowerCase() == 'admin').toList();
    final sessionChats = _items.where((c) => c.kind.toLowerCase() == 'session').toList();

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: SmartAfyaPalette.primaryBlue,
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: CircularProgressIndicator(color: SmartAfyaPalette.primaryBlue),
                  ),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _load,
                              style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (adminChats.isNotEmpty) ...[
                        _sectionLabel('Admin & coordination'),
                        ...adminChats.map((c) => _ConversationTile(
                              item: c,
                              timeLabel: _formatTimestamp(c.lastMessageAt),
                              onTap: () => _openThread(c),
                            )),
                        const SizedBox(height: 16),
                      ],
                      if (sessionChats.isNotEmpty) ...[
                        _sectionLabel('Session chats'),
                        ...sessionChats.map((c) => _ConversationTile(
                              item: c,
                              timeLabel: _formatTimestamp(c.lastMessageAt),
                              onTap: () => _openThread(c),
                            )),
                      ],
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 64),
                          child: Center(
                            child: Text(
                              _emptyHint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: SmartAfyaPalette.mutedText,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Future<void> _openThread(ChatConversationDto c) async {
    final uid = _userId;
    if (uid == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(
          conversation: c,
          currentUserId: uid,
        ),
      ),
    );
    await _load();
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: SmartAfyaPalette.mutedText,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.item,
    required this.timeLabel,
    required this.onTap,
  });

  final ChatConversationDto item;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = (item.lastMessagePreview ?? '').trim().isEmpty ? 'No messages yet' : item.lastMessagePreview!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4EEF7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: SmartAfyaPalette.softBlue,
                  child: Icon(
                    item.kind.toLowerCase() == 'admin' ? Icons.support_agent_rounded : Icons.medical_services_outlined,
                    color: SmartAfyaPalette.primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeLabel.isNotEmpty)
                            Text(
                              timeLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: SmartAfyaPalette.mutedText,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: SmartAfyaPalette.mutedText.withValues(alpha: item.isExpired ? 0.55 : 1),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.isExpired && item.kind.toLowerCase() == 'session')
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Session chat closed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: SmartAfyaPalette.mutedText,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
