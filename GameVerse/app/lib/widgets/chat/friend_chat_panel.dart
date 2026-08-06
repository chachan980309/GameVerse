import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/presence_controller.dart';
import '../../controllers/voice_room_controller.dart';
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
    final messages = _messages ??= _service.getConversation(
      profile['id'].toString(),
    );

    return ListenableBuilder(
      listenable: PresenceController.instance,
      builder: (context, _) {
        final online = PresenceController.instance.isUserOnline(profile['id'].toString());
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
                      onPressed: () {
                        print("[STEP 1] Botón de llamada pulsado en FriendChatPanel");
                        print("[STEP 1] ID del receptor: ${profile['id']}");
                        VoiceRoomController.instance.startPrivateCall(profile);
                      },
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
              _activeCallHeaderWidget(profile),
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
      },
    );
  }

  Widget _activeCallHeaderWidget(Map<String, dynamic> profile) {
    return ListenableBuilder(
      listenable: VoiceRoomController.instance,
      builder: (context, _) {
        final vc = VoiceRoomController.instance;
        final profileId = profile['id']?.toString() ?? '';
        if (!vc.isConnected || !vc.isPrivateCall || vc.privateCallUser?['id']?.toString() != profileId) {
          return const SizedBox.shrink();
        }

        final otherName = (profile['username'] ?? profile['name'] ?? 'Usuario').toString();
        final otherAvatar = profile['avatar_url']?.toString() ?? '';

        final isOtherSpeaking = vc.activeSpeakerId == profileId;
        final isMeSpeaking = vc.activeSpeakerId == Supabase.instance.client.auth.currentUser?.id;

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xff1f1a2e),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xff55338b), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2a000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xff50e6a5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LLAMADA PRIVADA ACTIVA',
                    style: TextStyle(color: Color(0xff50e6a5), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Tu Avatar
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isMeSpeaking ? const Color(0xff8b4dff) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: const CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xff6d35f5),
                          child: Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tú',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                  const Icon(Icons.swap_horiz_rounded, color: Colors.white38),
                  // Su Avatar
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isOtherSpeaking ? const Color(0xff8b4dff) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xff6d35f5),
                          backgroundImage: otherAvatar.isNotEmpty ? NetworkImage(otherAvatar) : null,
                          child: otherAvatar.isEmpty
                              ? Text(otherName.isEmpty ? '?' : otherName[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        otherName,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Silenciar
                  _quickActionBtn(
                    icon: vc.microphoneMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    active: vc.microphoneMuted,
                    color: vc.microphoneMuted ? const Color(0xffd64a68) : const Color(0xff3b3154),
                    onTap: vc.toggleMute,
                  ),
                  const SizedBox(width: 8),
                  // Enmudecer
                  _quickActionBtn(
                    icon: vc.deafened ? Icons.headset_off_rounded : Icons.headphones_rounded,
                    active: vc.deafened,
                    color: vc.deafened ? const Color(0xffd64a68) : const Color(0xff3b3154),
                    onTap: vc.toggleDeafen,
                  ),
                  const SizedBox(width: 8),
                  // Pantalla compartida
                  _quickActionBtn(
                    icon: vc.isScreenSharing ? Icons.screen_share_rounded : Icons.stop_screen_share_rounded,
                    active: vc.isScreenSharing,
                    color: vc.isScreenSharing ? const Color(0xff50e6a5) : const Color(0xff3b3154),
                    onTap: vc.toggleScreenShare,
                  ),
                  const SizedBox(width: 16),
                  // Colgar
                  _quickActionBtn(
                    icon: Icons.call_end_rounded,
                    active: true,
                    color: const Color(0xffd64a68),
                    onTap: vc.endPrivateCall,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _quickActionBtn({
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
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
