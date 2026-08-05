import 'package:flutter/material.dart';

import '../../models/direct_message.dart';
import '../../services/direct_message_service.dart';
import 'shared_post_message_card.dart';

Future<void> showDirectMessageSheet(
  BuildContext context, {
  required String userId,
  required String username,
  required String avatarUrl,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFF171421),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => _DirectMessageSheet(
    userId: userId,
    username: username,
    avatarUrl: avatarUrl,
  ),
);

class _DirectMessageSheet extends StatefulWidget {
  const _DirectMessageSheet({
    required this.userId,
    required this.username,
    required this.avatarUrl,
  });

  final String userId;
  final String username;
  final String avatarUrl;

  @override
  State<_DirectMessageSheet> createState() => _DirectMessageSheetState();
}

class _DirectMessageSheetState extends State<_DirectMessageSheet> {
  final _service = DirectMessageService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late Future<List<DirectMessage>> _messages = _service.getConversation(
    widget.userId,
  );
  bool _sending = false;
  bool _didInitialScroll = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _didInitialScroll = false;
      _messages = _service.getConversation(widget.userId);
    });
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
    if (_sending || _controller.text.trim().isEmpty) return;
    final content = _controller.text;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(widget.userId, content);
      _controller.clear();
      _reload();
      _scrollToLatest(animated: true);
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
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .72,
    minChildSize: .45,
    maxChildSize: .94,
    expand: false,
    builder: (context, sheetController) => Column(
      children: [
        Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF6D35F5),
                backgroundImage: widget.avatarUrl.isEmpty
                    ? null
                    : NetworkImage(widget.avatarUrl),
                child: widget.avatarUrl.isEmpty
                    ? Text(
                        widget.username.isEmpty
                            ? '?'
                            : widget.username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF39324F)),
        Expanded(
          child: FutureBuilder<List<DirectMessage>>(
            future: _messages,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6D35F5)),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'No se pudieron cargar los mensajes.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    'Aún no hay mensajes. Saluda primero.',
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
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
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
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF252133),
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
                          width: 20,
                          height: 20,
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
        ),
      ],
    ),
  );
}
