import 'package:flutter/material.dart';

import '../models/direct_message.dart';
import '../services/direct_message_service.dart';
import '../services/friend_service.dart';
import '../widgets/chat/shared_post_message_card.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, this.showChat = true, this.onFriendSelected});

  final bool showChat;
  final ValueChanged<Map<String, dynamic>>? onFriendSelected;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  // Same palette used by MainScreen, Sidebar and the existing profile cards.
  static const _background = Color(0xFF17141F);
  static const _surface = Color(0xFF1D1B20);
  static const _purple = Color(0xFF6438FF);
  final FriendService _friendService = FriendService();
  final DirectMessageService _messageService = DirectMessageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  bool _loading = true;
  int _selectedTab = 0;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _blocked = [];
  Map<String, String> _outgoingByUserId = {};
  Map<String, dynamic>? _activeChatProfile;
  Future<List<DirectMessage>>? _chatMessages;
  bool _sendingMessage = false;
  bool _didInitialChatScroll = false;

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _friendService.getAcceptedFriends(),
        _friendService.getPendingRequests(),
        _friendService.getBlockedUsers(),
        _friendService.getOutgoingRequests(),
      ]);
      if (!mounted) return;
      final outgoing = List<Map<String, dynamic>>.from(results[3]);
      setState(() {
        _friends = List<Map<String, dynamic>>.from(results[0]);
        _pending = List<Map<String, dynamic>>.from(results[1]);
        _blocked = List<Map<String, dynamic>>.from(results[2]);
        _outgoingByUserId = {
          for (final request in outgoing)
            request['receiver_id'] as String: request['id'] as String,
        };
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _runAction(Future<void> action, String message) async {
    try {
      await action;
      await _loadData();
      if (mounted) _showMessage(message);
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final body = switch (_selectedTab) {
      0 => _friendsList(_friends),
      1 => _friendsList(_friends.where(_isOnline).toList()),
      2 => _friendsList(_friends.where(_isPlaying).toList()),
      3 => _pendingList(),
      _ => _blockedList(),
    };

    return Container(
      color: _background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Amigos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _tabButton('Todos', Icons.group_outlined, 0),
                        _tabButton(
                          'En línea',
                          Icons.circle,
                          1,
                          activeIconColor: const Color(0xFF1ED760),
                        ),
                        _tabButton('Jugando', Icons.sports_esports_outlined, 2),
                        _tabButton(
                          'Pendientes',
                          Icons.person_add_alt_1_outlined,
                          3,
                          count: _pending.length,
                        ),
                        _tabButton('Bloqueados', Icons.block_outlined, 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _showAddFriendDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Agregar amigo'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: widget.showChat
                  ? Row(
                      children: [
                        Expanded(child: body),
                        const SizedBox(width: 18),
                        SizedBox(width: 370, child: _chatPanel()),
                      ],
                    )
                  : body,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(
    String label,
    IconData icon,
    int index, {
    int? count,
    Color? activeIconColor,
  }) {
    final selected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? _purple : _surface,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () => setState(() => _selectedTab = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected
                      ? Colors.white
                      : (activeIconColor ?? Colors.white70),
                ),
                const SizedBox(width: 6),
                Text(
                  '$label${count == null ? '' : ' ($count)'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _friendsList(List<Map<String, dynamic>> friendships) {
    if (friendships.isEmpty) return _emptyState('No hay amigos para mostrar.');
    return ListView.separated(
      itemCount: friendships.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final friendship = friendships[index];
        final profile = _otherProfile(friendship);
        return _personCard(
          profile: profile,
          onTap: () => _openChat(profile),
          trailing: PopupMenuButton<String>(
            color: const Color(0xFF242332),
            icon: const Icon(Icons.more_horiz, color: Colors.white70),
            onSelected: (action) {
              if (action == 'remove') {
                _runAction(
                  _friendService.removeFriend(friendship['id'] as String),
                  'Amigo eliminado',
                );
              }
              if (action == 'block') {
                _runAction(
                  _friendService.blockUser(friendship['id'] as String),
                  'Usuario bloqueado',
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remove', child: Text('Eliminar amigo')),
              PopupMenuItem(value: 'block', child: Text('Bloquear')),
            ],
          ),
        );
      },
    );
  }

  Widget _pendingList() {
    if (_pending.isEmpty) {
      return _emptyState('No tienes solicitudes recibidas.');
    }
    return ListView.separated(
      itemCount: _pending.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final request = _pending[index];
        return _personCard(
          profile: Map<String, dynamic>.from(request['sender'] as Map),
          subtitle: 'Te envió una solicitud de amistad',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _runAction(
                  _friendService.rejectRequest(request['id'] as String),
                  'Solicitud rechazada',
                ),
                child: const Text('Rechazar'),
              ),
              FilledButton(
                onPressed: () => _runAction(
                  _friendService.acceptRequest(request['id'] as String),
                  'Solicitud aceptada',
                ),
                style: FilledButton.styleFrom(backgroundColor: _purple),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blockedList() {
    if (_blocked.isEmpty) {
      return _emptyState('No has bloqueado a ningún usuario.');
    }
    return ListView.separated(
      itemCount: _blocked.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final friendship = _blocked[index];
        return _personCard(
          profile: _otherProfile(friendship),
          subtitle: 'Usuario bloqueado',
          trailing: OutlinedButton(
            onPressed: () => _runAction(
              _friendService.removeFriend(friendship['id'] as String),
              'Usuario desbloqueado',
            ),
            child: const Text('Desbloquear'),
          ),
        );
      },
    );
  }

  Widget _personCard({
    required Map<String, dynamic> profile,
    required Widget trailing,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final online = _profileOnline(profile);
    final game = _profileGame(profile);
    final displaySubtitle =
        subtitle ??
        (game.isNotEmpty
            ? 'Jugando $game'
            : (online ? 'En línea' : 'Desconectado'));
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              _avatar(profile),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _name(profile),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (online)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text(
                              '• En línea',
                              style: TextStyle(
                                color: Color(0xFF1ED760),
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displaySubtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> profile) {
    final url = profile['avatar_url']?.toString();
    return CircleAvatar(
      radius: 20,
      backgroundColor: _purple,
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? Text(
              _name(profile).isEmpty ? '?' : _name(profile)[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            )
          : null,
    );
  }

  void _openChat(Map<String, dynamic> profile) {
    if (widget.onFriendSelected != null) {
      widget.onFriendSelected!(profile);
      return;
    }
    final userId = profile['id']?.toString();
    if (userId == null || userId.isEmpty) return;
    setState(() {
      _activeChatProfile = profile;
      _didInitialChatScroll = false;
      _chatMessages = _messageService.getConversation(userId);
    });
  }

  Future<void> _sendChatMessage() async {
    final userId = _activeChatProfile?['id']?.toString();
    if (_sendingMessage ||
        userId == null ||
        _messageController.text.trim().isEmpty) {
      return;
    }
    setState(() => _sendingMessage = true);
    try {
      await _messageService.sendMessage(userId, _messageController.text);
      _messageController.clear();
      if (!mounted) return;
      setState(() {
        _didInitialChatScroll = false;
        _chatMessages = _messageService.getConversation(userId);
      });
      _scrollChatToLatest(animated: true);
    } catch (error) {
      if (mounted) _showMessage('No se pudo enviar: $error', isError: true);
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  void _scrollChatToLatest({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      final offset = _chatScrollController.position.maxScrollExtent;
      if (animated) {
        _chatScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _chatScrollController.jumpTo(offset);
      }
    });
  }

  Widget _chatPanel() {
    final profile = _activeChatProfile;
    if (profile == null) {
      return Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined, color: Color(0xFF9A78FF), size: 38),
                SizedBox(height: 12),
                Text(
                  'Selecciona un amigo para abrir el chat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final userId = profile['id'].toString();
    final messages = _chatMessages ?? _messageService.getConversation(userId);
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF312D3E)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _avatar(profile),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name(profile),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _profileOnline(profile) ? 'En línea' : 'Desconectado',
                        style: TextStyle(
                          color: _profileOnline(profile)
                              ? const Color(0xFF1ED760)
                              : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _activeChatProfile = null),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
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
                    child: CircularProgressIndicator(color: _purple),
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
                if (!_didInitialChatScroll) {
                  _didInitialChatScroll = true;
                  _scrollChatToLatest();
                }
                return ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: chat.length,
                  itemBuilder: (context, index) {
                    final message = chat[index];
                    final mine =
                        message.senderId == _messageService.currentUserId;
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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _sendChatMessage(),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF15141D),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                IconButton(
                  onPressed: _sendingMessage ? null : _sendChatMessage,
                  icon: _sendingMessage
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
                  style: IconButton.styleFrom(backgroundColor: _purple),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddFriendDialog() async {
    final users = await _friendService.searchUsers();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF171725),
          title: const Text(
            'Agregar amigo',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 460,
            child: users.isEmpty
                ? const Text(
                    'No hay otros usuarios registrados.',
                    style: TextStyle(color: Colors.white70),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: users.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white12),
                    itemBuilder: (_, index) {
                      final user = users[index];
                      final userId = user['id'] as String;
                      final requestId = _outgoingByUserId[userId];
                      final alreadyFriend = _friends.any(
                        (friendship) =>
                            _otherProfile(friendship)['id'] == userId,
                      );
                      final blocked = _blocked.any(
                        (friendship) =>
                            _otherProfile(friendship)['id'] == userId,
                      );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _avatar(user),
                        title: Text(
                          _name(user),
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          user['email']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: requestId != null
                            ? TextButton.icon(
                                onPressed: () async {
                                  await _runAction(
                                    _friendService.cancelFriendRequest(
                                      requestId,
                                    ),
                                    'Solicitud cancelada',
                                  );
                                  setDialogState(() {});
                                },
                                icon: const Icon(
                                  Icons.check,
                                  color: Color(0xFF1ED760),
                                ),
                                label: const Text('Cancelar solicitud'),
                              )
                            : alreadyFriend
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF1ED760),
                              )
                            : blocked
                            ? const Icon(Icons.block, color: Colors.redAccent)
                            : FilledButton.icon(
                                onPressed: () async {
                                  await _runAction(
                                    _friendService
                                        .sendFriendRequest(userId)
                                        .then((_) {}),
                                    'Solicitud enviada',
                                  );
                                  setDialogState(() {});
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _purple,
                                ),
                                icon: const Icon(Icons.person_add, size: 17),
                                label: const Text('Agregar'),
                              ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _otherProfile(Map<String, dynamic> friendship) {
    final isSender = friendship['sender_id'] == _friendService.currentUserId;
    return Map<String, dynamic>.from(
      isSender ? friendship['receiver'] as Map : friendship['sender'] as Map,
    );
  }

  bool _isOnline(Map<String, dynamic> friendship) =>
      _profileOnline(_otherProfile(friendship));
  bool _isPlaying(Map<String, dynamic> friendship) =>
      _profileGame(_otherProfile(friendship)).isNotEmpty;
  bool _profileOnline(Map<String, dynamic> profile) =>
      profile['is_online'] == true || profile['online'] == true;
  String _profileGame(Map<String, dynamic> profile) =>
      (profile['current_game'] ?? profile['game'] ?? profile['game_name'] ?? '')
          .toString();
  String _name(Map<String, dynamic> profile) =>
      (profile['username'] ?? profile['name'] ?? 'Usuario').toString();
  Widget _emptyState(String message) => Center(
    child: Text(message, style: const TextStyle(color: Colors.white54)),
  );
  void _showMessage(String message, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : _purple,
        ),
      );
}
