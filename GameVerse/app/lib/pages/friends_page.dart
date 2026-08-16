import 'package:flutter/material.dart';

import '../controllers/presence_controller.dart';
import '../models/direct_message.dart';
import '../services/direct_message_service.dart';
import '../services/friend_service.dart';
import '../services/profile_navigation_service.dart';
import '../services/app_media_service.dart';
import '../services/global_search_focus_service.dart';
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
  final TextEditingController _userSearchController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  bool _loading = true;
  int _selectedTab = 0;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _blocked = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  Map<String, String> _outgoingByUserId = {};
  Map<String, dynamic>? _activeChatProfile;
  Future<List<DirectMessage>>? _chatMessages;
  bool _sendingMessage = false;
  bool _didInitialChatScroll = false;
  bool _showUserSearch = false;
  bool _searchingUsers = false;
  List<Map<String, dynamic>> _userSearchResults = const [];
  String? _heroImageUrl;

  @override
  void dispose() {
    _messageController.dispose();
    _userSearchController.dispose();
    _chatScrollController.dispose();
    PresenceController.instance.removeListener(_onPresenceChanged);
    super.dispose();
  }

  Future<void> _searchUsers(String value) async {
    final query = value.trim().toLowerCase();
    if (query.length < 2) {
      if (mounted) setState(() => _userSearchResults = const []);
      return;
    }
    setState(() => _searchingUsers = true);
    try {
      final users = await _friendService.searchUsers();
      final results = users
          .where((user) {
            final id = user['id']?.toString() ?? '';
            final name = user['username']?.toString().toLowerCase() ?? '';
            return name.contains(query) &&
                !_friends.any(
                  (friendship) => _otherProfile(friendship)['id'] == id,
                ) &&
                !_outgoingByUserId.containsKey(id);
          })
          .take(5)
          .toList();
      if (mounted) setState(() => _userSearchResults = results);
    } finally {
      if (mounted) setState(() => _searchingUsers = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadHeroImage();
    PresenceController.instance.addListener(_onPresenceChanged);
  }

  Future<void> _loadHeroImage() async {
    final url = await AppMediaService.instance.publicUrlFor(
      'friends_hero_background',
    );
    if (mounted) setState(() => _heroImageUrl = url);
  }

  void _onPresenceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _friendService.getAcceptedFriends(),
        _friendService.getPendingRequests(),
        _friendService.getBlockedUsers(),
        _friendService.getOutgoingRequests(),
        _friendService.getSuggestedFriends(),
      ]);
      if (!mounted) return;
      final outgoing = List<Map<String, dynamic>>.from(results[3]);
      final suggested = List<Map<String, dynamic>>.from(results[4]);
      setState(() {
        _friends = List<Map<String, dynamic>>.from(results[0]);
        _pending = List<Map<String, dynamic>>.from(results[1]);
        _blocked = List<Map<String, dynamic>>.from(results[2]);
        _outgoingByUserId = {
          for (final request in outgoing)
            request['receiver_id'] as String: request['id'] as String,
        };
        _suggestedUsers = suggested;
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
            _friendsHero(),
            const SizedBox(height: 14),
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
                  onPressed: GlobalSearchFocusService.instance.requestFocus,
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
            const SizedBox(height: 14),
            Expanded(
              child: widget.showChat
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 900) {
                          return _activeChatProfile == null
                              ? body
                              : _chatPanel();
                        }
                        return Row(
                          children: [
                            Expanded(child: body),
                            const SizedBox(width: 18),
                            SizedBox(width: 330, child: _friendsSidePanel()),
                          ],
                        );
                      },
                    )
                  : body,
            ),
          ],
        ),
      ),
    );
  }

  Widget _friendsSidePanel() => _activeChatProfile != null
      ? _chatPanel()
      : SingleChildScrollView(
          child: Column(
            children: [
              _sideCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Agregar amigo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Color(0xff9c70ff),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Busca por nombre de usuario',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => setState(() {
                        _showUserSearch = !_showUserSearch;
                        _userSearchResults = const [];
                        _userSearchController.clear();
                      }),
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        minimumSize: const Size.fromHeight(40),
                      ),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Buscar usuario'),
                    ),
                    if (_showUserSearch) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _userSearchController,
                        autofocus: true,
                        onChanged: _searchUsers,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Escribe un nombre...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: Color(0xffb58aff),
                          ),
                          filled: true,
                          fillColor: const Color(0xff12101c),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (_searchingUsers)
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ..._userSearchResults.map(_searchResultRow),
                      if (!_searchingUsers &&
                          _userSearchController.text.trim().length >= 2 &&
                          _userSearchResults.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'No se encontraron usuarios.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _sideCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Solicitudes de amistad',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pending.isEmpty
                          ? 'No tienes solicitudes pendientes'
                          : 'Tienes ${_pending.length} solicitud${_pending.length == 1 ? '' : 'es'} pendiente${_pending.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    if (_pending.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() => _selectedTab = 3),
                        child: const Text('Ver solicitudes'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _sideCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Amigos sugeridos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_suggestedUsers.isEmpty)
                      const Text(
                        'No hay sugerencias nuevas por ahora.',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ..._suggestedUsers.map(_suggestedUserRow),
                  ],
                ),
              ),
            ],
          ),
        );

  Widget _sideCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xff1b1829),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xff5f35b9).withOpacity(.35)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.18),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );

  Widget _suggestedUserRow(Map<String, dynamic> user) => Padding(
    padding: const EdgeInsets.only(top: 11),
    child: Row(
      children: [
        _avatar(user),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name(user),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                user['mutual_friends'] == null
                    ? 'Jugador recomendado para ti'
                    : '${user['mutual_friends']} amigo${user['mutual_friends'] == 1 ? '' : 's'} en común',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
        FilledButton(
          onPressed: () => _runAction(
            _friendService
                .sendFriendRequest(user['id'].toString())
                .then((_) {}),
            'Solicitud enviada',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff6c35ff),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            minimumSize: const Size(72, 36),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: const Text('Agregar', style: TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );

  Widget _searchResultRow(Map<String, dynamic> user) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        _avatar(user),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _name(user),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Enviar solicitud',
          onPressed: () => _runAction(
            _friendService
                .sendFriendRequest(user['id'].toString())
                .then((_) {}),
            'Solicitud enviada',
          ),
          icon: const Icon(
            Icons.person_add_alt_1_rounded,
            color: Color(0xffad7bff),
            size: 19,
          ),
        ),
      ],
    ),
  );

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

  Widget _friendsHero() => SizedBox(
    height: 132,
    width: double.infinity,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xff16082f), Color(0xff2d1160), Color(0xff110b22)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: const Color(0xff7544df).withOpacity(.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_heroImageUrl != null)
            Positioned.fill(
              child: Image.network(
                _heroImageUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xff16082f).withOpacity(.96),
                    const Color(0xff16082f).withOpacity(.62),
                    const Color(0xff16082f).withOpacity(.08),
                  ],
                  stops: const [0, .48, 1],
                ),
              ),
            ),
          ),
          Positioned(
            right: 42,
            bottom: -22,
            child: Icon(
              Icons.groups_rounded,
              size: 145,
              color: const Color(0xffa875ff).withOpacity(.20),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Amigos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Conecta, juega y comparte momentos increíbles',
                  style: TextStyle(color: Color(0xffc8b5eb), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

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
        final profile = Map<String, dynamic>.from(request['sender'] as Map);
        return _personCard(
          profile: profile,
          subtitle: 'Te envió una solicitud de amistad',
          onTap: () {
            final userId = profile['id']?.toString();
            if (userId != null && userId.isNotEmpty) {
              ProfileNavigationService.instance.openProfile(userId);
            }
          },
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
            : (online ? 'En línea' : _lastSeenText(profile)));
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: online
                  ? [const Color(0xff211b35), const Color(0xff171625)]
                  : [const Color(0xff1d1b26), const Color(0xff17151e)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: online
                  ? const Color(0xff5e37b4).withOpacity(.40)
                  : Colors.white.withOpacity(.055),
            ),
            boxShadow: online
                ? [
                    BoxShadow(
                      color: const Color(0xff7946f5).withOpacity(.10),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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

  void _openProfile(Map<String, dynamic> profile) {
    final userId = profile['id']?.toString();
    if (userId == null || userId.isEmpty) return;
    ProfileNavigationService.instance.openProfile(userId);
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
                Expanded(
                  child: InkWell(
                    onTap: () => _openProfile(profile),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
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
                                  _profileOnline(profile)
                                      ? 'En línea'
                                      : 'Desconectado',
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
                        ],
                      ),
                    ),
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
  bool _profileOnline(Map<String, dynamic> profile) {
    final id = profile['id']?.toString() ?? '';
    return PresenceController.instance.isUserOnline(id);
  }

  String _lastSeenText(Map<String, dynamic> profile) {
    final rawDate =
        profile['last_seen_at']?.toString() ?? profile['last_seen']?.toString();
    if (rawDate == null || rawDate.isEmpty) return 'Desconectado';
    final date = DateTime.tryParse(rawDate);
    if (date == null) return 'Desconectado';

    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Última vez hace un momento';
    if (diff.inMinutes < 60) return 'Última vez hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Última vez hace ${diff.inHours} h';
    final days = diff.inDays;
    if (days == 1) return 'Última vez ayer';
    return 'Última vez hace $days días';
  }

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
