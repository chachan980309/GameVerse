import 'package:flutter/material.dart';

import '../../models/direct_message.dart';
import '../../services/direct_message_service.dart';
import 'shared_post_message_card.dart';

class FriendChatPanel extends StatefulWidget {
  const FriendChatPanel({
    super.key,
    required this.profile,
    required this.onClose,
  });

  final Map<String, dynamic>? profile;
  final VoidCallback onClose;

  @override
  State<FriendChatPanel> createState() => _FriendChatPanelState();
}

class _FriendChatPanelState extends State<FriendChatPanel> {
  final _service = DirectMessageService();
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  Future<List<DirectMessage>>? _messages;
  bool _sending = false;
  bool _didInitialScroll = false;

  @override
  void didUpdateWidget(covariant FriendChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?['id'] != widget.profile?['id']) {
      final id = widget.profile?['id']?.toString();
      _didInitialScroll = false;
      _messages = id == null ? null : _service.getConversation(id);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final offset = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(offset);
      }
    });
  }

  Future<void> _send() async {
    final userId = widget.profile?['id']?.toString();
    if (_sending || userId == null || _input.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(userId, _input.text);
      _input.clear();
      if (mounted) {
        setState(() {
          _didInitialScroll = false;
          _messages = _service.getConversation(userId);
        });
        _scrollToLatest(animated: true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo enviar: $error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    if (profile == null) return _empty();
    final name = (profile['username'] ?? profile['name'] ?? 'Usuario')
        .toString();
    final avatar = profile['avatar_url']?.toString() ?? '';
    final online = profile['is_online'] == true || profile['online'] == true;
    final messages = _messages ??= _service.getConversation(
      profile['id'].toString(),
    );

    return Container(
      color: const Color(0xFF14121D),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white70,
                  ),
                ),
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFF6D35F5),
                  backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                  child: avatar.isEmpty
                      ? Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        online ? 'En línea' : 'Desconectado',
                        style: TextStyle(
                          color: online
                              ? const Color(0xFF1ED760)
                              : Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.call_outlined, color: Colors.white70),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.videocam_outlined,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF312D3E)),
          Expanded(
            child: FutureBuilder<List<DirectMessage>>(
              future: messages,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6D35F5)),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'No se pudo cargar el chat.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                final chat = snapshot.data ?? [];
                if (chat.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aún no hay mensajes.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                if (!_didInitialScroll) {
                  _didInitialScroll = true;
                  _scrollToLatest();
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(14),
                  itemCount: chat.length,
                  itemBuilder: (context, index) {
                    final message = chat[index];
                    final mine = message.senderId == _service.currentUserId;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ChatMessageBubble(message: message, mine: mine),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF242131),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF6D35F5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Container(
    color: const Color(0xFF14121D),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, color: Color(0xFF9A78FF), size: 40),
          SizedBox(height: 12),
          Text(
            'Selecciona un amigo para abrir el chat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    ),
  );
}
