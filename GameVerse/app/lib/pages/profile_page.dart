import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post_model.dart';
import '../models/user_game.dart';
import '../controllers/video_feed_controller.dart';
import '../pages/image_viewer_page.dart';
import '../services/friend_service.dart';
import '../services/direct_message_service.dart';
import '../services/post_service.dart';
import '../services/user_games_service.dart';
import '../utils/game_catalog.dart';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/profile_tabs.dart';
import '../widgets/posts/video_player_widget.dart';
import '../widgets/posts/post_card.dart';
import '../widgets/chat/direct_message_sheet.dart';
import 'profile/tabs/clips_tab.dart';
import 'profile/tabs/games_tab.dart';
import 'profile/tabs/information_tab.dart';
import 'profile/tabs/photos_tab.dart';
import 'profile/tabs/wall_tab.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.userId});

  /// A null value renders the authenticated user's existing editable profile.
  final String? userId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedTab = 0;
  bool _headerCollapsed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.userId != null)
      return _PublicProfilePage(userId: widget.userId!);

    return Scaffold(
      backgroundColor: const Color(0xFF17141F),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: _headerCollapsed ? 112 : 216,
              child: ProfileHeader(collapsed: _headerCollapsed),
            ),
            ProfileTabs(
              selectedIndex: _selectedTab,
              onTabSelected: (index) => setState(() => _selectedTab = index),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis != Axis.vertical) return false;
                  final shouldCollapse = notification.metrics.pixels > 25;
                  if (shouldCollapse != _headerCollapsed) {
                    setState(() => _headerCollapsed = shouldCollapse);
                  }
                  return false;
                },
                child: IndexedStack(
                  index: _selectedTab,
                  children: const [
                    WallTab(),
                    GamesTab(),
                    ClipsTab(),
                    PhotosTab(),
                    InformationTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicProfilePage extends StatefulWidget {
  const _PublicProfilePage({required this.userId});

  final String userId;

  @override
  State<_PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<_PublicProfilePage> {
  late Future<_PublicProfileData?> _profileData;
  final VideoFeedController _videoController = VideoFeedController();
  int _selectedTab = 0;
  bool _sendingRequest = false;
  bool _relationshipLoading = true;
  Map<String, dynamic>? _relationship;

  @override
  void initState() {
    super.initState();
    _profileData = _loadProfile();
    _loadRelationship();
  }

  @override
  void didUpdateWidget(covariant _PublicProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _profileData = _loadProfile();
      _loadRelationship();
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<_PublicProfileData?> _loadProfile() async {
    final rawProfile = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', widget.userId)
        .maybeSingle();
    if (rawProfile == null) return null;

    List<PostModel> posts = [];
    List<UserGame> games = [];
    var friendCount = 0;
    var gameCount = 0;
    try {
      posts = await PostService().getUserPosts(widget.userId);
    } catch (_) {
      // The public profile remains visible when posts are restricted by RLS.
    }
    try {
      final counts = await Future.wait([
        FriendService().countAcceptedFriends(widget.userId),
        UserGamesService().getGamesForUser(widget.userId),
      ]);
      friendCount = counts[0] as int;
      games = counts[1] as List<UserGame>;
      gameCount = games.length;
    } catch (_) {
      // A profile is still useful if relationship or game policies are restricted.
    }
    return _PublicProfileData(
      profile: Map<String, dynamic>.from(rawProfile),
      posts: posts,
      friendCount: friendCount,
      gameCount: gameCount,
      games: games,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F0E17),
      child: FutureBuilder<_PublicProfileData?>(
        future: _profileData,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Text(
                'No pudimos cargar este perfil.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _profileHeader(data.profile),
              _publicTabs(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                child: _publicTabContent(data),
              ),
              /*
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Publicaciones', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (data.posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('Este usuario aún no tiene publicaciones.', style: TextStyle(color: Colors.white54))),
                    )
                  else
                    ...data.posts.map(_postCard),
                ]),
              ),
              */
            ],
          );
        },
      ),
    );
  }

  Widget _profileHeader(Map<String, dynamic> profile) {
    final bannerUrl = profile['banner_url']?.toString() ?? '';
    final avatarUrl = profile['avatar_url']?.toString() ?? '';
    final username = profile['username']?.toString() ?? 'Usuario';
    final status = profile['status']?.toString() ?? '';
    final handle = profile['handle']?.toString() ?? '';
    final motto = profile['motto']?.toString() ?? '';
    final online =
        status.toLowerCase().contains('online') ||
        status.toLowerCase().contains('línea');

    return SizedBox(
      height: 322,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFF111019))),
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            // El banner ocupa toda la cabecera: no queda una franja vacía
            // entre las acciones del perfil y las pestañas.
            height: 322,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF211D2E),
                    child: bannerUrl.isEmpty
                        ? null
                        : Image.network(
                            bannerUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(),
                          ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFF111019).withValues(alpha: .82),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 28,
            top: 112,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF7C3AED),
              ),
              child: CircleAvatar(
                radius: 67,
                backgroundColor: const Color(0xFF29233A),
                backgroundImage: avatarUrl.isEmpty
                    ? null
                    : NetworkImage(avatarUrl),
                child: avatarUrl.isEmpty
                    ? Text(
                        username.isEmpty ? '?' : username[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            left: 190,
            right: 28,
            top: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                  ],
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: online ? Colors.greenAccent : Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.isEmpty ? 'En línea' : status,
                        style: TextStyle(
                          color: online ? Colors.greenAccent : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ],
                if (handle.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    '@$handle',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
                if (motto.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    motto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 190,
            right: 28,
            top: 230,
            child: Row(
              children: [
                _friendButton(),
                const SizedBox(width: 10),
                _actionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Mensaje',
                  onPressed: () => _openMessages(profile),
                ),
                const SizedBox(width: 10),
                _actionButton(
                  icon: Icons.sports_esports_rounded,
                  label: 'Invitar a jugar',
                  onPressed: () => _inviteToPlay(profile),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Compartir perfil',
                  onPressed: () => _shareProfile(profile),
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1A29),
                    side: const BorderSide(color: Color(0xFF4A3B68)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Más opciones',
                  onPressed: _showFriendMenu,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white70,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1A29),
                    side: const BorderSide(color: Color(0xFF4A3B68)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _publicTabs() => Container(
    height: 54,
    decoration: const BoxDecoration(
      color: Color(0xFF151420),
      border: Border(bottom: BorderSide(color: Color(0xFF292638))),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _publicTabLabels.length,
        (index) => _ProfileTab(
          label: _publicTabLabels[index],
          selected: _selectedTab == index,
          onTap: () => setState(() => _selectedTab = index),
        ),
      ),
    ),
  );

  static const _publicTabLabels = ['Muro', 'Juegos', 'Clips', 'Fotos', 'Info'];

  Widget _publicTabContent(_PublicProfileData data) {
    switch (_selectedTab) {
      case 1:
        return _publicGames(data.games);
      case 2:
        return _publicClips(data.posts);
      case 3:
        return _publicPhotos(data.posts);
      case 4:
        return _aboutCard(data.profile);
      default:
        return _wall(data.profile, data.posts);
    }
  }

  Widget _tabs() => Container(
    height: 54,
    decoration: const BoxDecoration(
      color: Color(0xFF151420),
      border: Border(bottom: BorderSide(color: Color(0xFF292638))),
    ),
    child: Row(
      children: [
        const SizedBox(width: 24),
        _ProfileTab(
          label: 'Muro',
          selected: _selectedTab == 0,
          onTap: () => setState(() => _selectedTab = 0),
        ),
        _ProfileTab(label: 'Información'),
      ],
    ),
  );

  Future<void> _openMessages(Map<String, dynamic> profile) =>
      showDirectMessageSheet(
        context,
        userId: widget.userId,
        username: profile['username']?.toString() ?? 'Usuario',
        avatarUrl: profile['avatar_url']?.toString() ?? '',
      );

  Future<void> _inviteToPlay(Map<String, dynamic> profile) async {
    final game = profile['favorite_game']?.toString().trim();
    try {
      await DirectMessageService().sendMessage(
        widget.userId,
        'Te invito a jugar${game == null || game.isEmpty ? '' : ' $game'} 🎮',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitación enviada por mensaje.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la invitación.')),
      );
    }
  }

  Future<void> _shareProfile(Map<String, dynamic> profile) async {
    final name = profile['username']?.toString() ?? 'este jugador';
    await Clipboard.setData(
      ClipboardData(
        text: 'Perfil de $name en nubzzz: usuario ${widget.userId}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Enlace del perfil copiado.')));
  }

  Future<void> _loadRelationship() async {
    setState(() => _relationshipLoading = true);
    try {
      final relationship = await FriendService().getRelationship(widget.userId);
      if (mounted) setState(() => _relationship = relationship);
    } finally {
      if (mounted) setState(() => _relationshipLoading = false);
    }
  }

  Widget _friendButton() {
    if (_relationshipLoading) {
      return _actionButton(
        icon: Icons.hourglass_top_rounded,
        label: 'Cargando...',
        primary: true,
        onPressed: null,
      );
    }

    final status = _relationship?['status']?.toString();
    final isOutgoing =
        _relationship?['sender_id'] ==
        Supabase.instance.client.auth.currentUser?.id;
    if (status == 'accepted') {
      return _actionButton(
        icon: Icons.people_alt_rounded,
        label: 'Amigos',
        primary: true,
        onPressed: _showFriendMenu,
      );
    }
    if (status == 'blocked') {
      return _actionButton(
        icon: Icons.block_rounded,
        label: 'Usuario bloqueado',
        primary: false,
        onPressed: null,
      );
    }
    if (status == 'pending' && isOutgoing) {
      return _actionButton(
        icon: Icons.cancel_outlined,
        label: 'Solicitud enviada · Cancelar',
        primary: false,
        onPressed: _cancelFriendRequest,
      );
    }
    if (status == 'pending') {
      return _actionButton(
        icon: Icons.mark_email_unread_outlined,
        label: 'Solicitud recibida',
        primary: true,
        onPressed: null,
      );
    }
    return _actionButton(
      icon: Icons.person_add_alt_1_rounded,
      label: 'Enviar solicitud',
      primary: true,
      onPressed: _sendingRequest ? null : _sendFriendRequest,
    );
  }

  Future<void> _showFriendMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                'Opciones de amistad',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.person_remove_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'Eliminar amigo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
            ListTile(
              leading: const Icon(
                Icons.block_rounded,
                color: Color(0xFFFF6B81),
              ),
              title: const Text(
                'Bloquear usuario',
                style: TextStyle(color: Color(0xFFFF6B81)),
              ),
              onTap: () => Navigator.pop(context, 'block'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'remove') {
      await _confirmRelationshipAction(
        title: '¿Eliminar amigo?',
        message: 'Dejarán de aparecer como amigos en nubzzz.',
        confirmLabel: 'Eliminar',
        operation: (id) => FriendService().removeFriend(id),
      );
    } else if (action == 'block') {
      await _confirmRelationshipAction(
        title: '¿Bloquear usuario?',
        message: 'No podrá enviarte solicitudes de amistad.',
        confirmLabel: 'Bloquear',
        operation: (id) => FriendService().blockUser(id),
        destructive: true,
      );
    }
  }

  Future<void> _confirmRelationshipAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function(String id) operation,
    bool destructive = false,
  }) async {
    final id = _relationship?['id']?.toString();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF211E2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive
                  ? const Color(0xFFD9435F)
                  : const Color(0xFF6D35F5),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sendingRequest = true);
    try {
      await operation(id);
      if (!mounted) return;
      await _loadRelationship();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$confirmLabel completado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    setState(() => _sendingRequest = true);
    try {
      await FriendService().sendFriendRequest(widget.userId);
      if (!mounted) return;
      await _loadRelationship();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud de amistad enviada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  Future<void> _cancelFriendRequest() async {
    final id = _relationship?['id']?.toString();
    if (id == null) return;
    setState(() => _sendingRequest = true);
    try {
      await FriendService().cancelFriendRequest(id);
      if (!mounted) return;
      await _loadRelationship();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitud cancelada.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  String _value(Map<String, dynamic> profile, String field) =>
      (profile[field] ?? 0).toString();

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool primary = false,
  }) => ElevatedButton.icon(
    onPressed: onPressed,
    icon: _sendingRequest && primary
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(icon, size: 18),
    label: Text(label),
    style: ElevatedButton.styleFrom(
      elevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: primary
          ? const Color(0xFF6D35F5)
          : const Color(0xFF1C1A29),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
  );

  Widget _metric(IconData icon, String value, String label) => Container(
    height: 62,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1827),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF302B42)),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF9A78FF), size: 22),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _statChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1A29),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFF343044)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9A78FF)),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _publicGames(List<UserGame> games) {
    if (games.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            'Este jugador aún no ha añadido juegos.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }
    return Column(
      children: games
          .map(
            (game) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF171625),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E2A40)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF30274B),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _publicGameLogo(game),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                game.gameName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (game.isFavorite)
                              const Padding(
                                padding: EdgeInsets.only(left: 7),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: Color(0xFFFFC14D),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (game.platform.isNotEmpty) game.platform,
                            if (game.rank?.isNotEmpty == true) game.rank!,
                            '${game.hoursPlayed} horas',
                          ].join(' · '),
                          style: const TextStyle(color: Colors.white54),
                        ),
                        if (game.gamerTag.isNotEmpty)
                          Text(
                            'Usuario: ${game.gamerTag}',
                            style: const TextStyle(
                              color: Color(0xFFBDAAFF),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _publicGameLogo(UserGame game) {
    final gameName = game.gameName;
    final fallback = Container(
      color: const Color(0xFF30274B),
      alignment: Alignment.center,
      child: Text(
        GameCatalog.badgeFor(gameName),
        style: const TextStyle(
          color: Color(0xFFBDAAFF),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (!game.imageUrl.startsWith('http')) return fallback;
    return Image.network(
      game.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _publicPhotos(List<PostModel> posts) {
    final photos = posts
        .where((post) => post.imageUrl?.isNotEmpty == true)
        .toList();
    if (photos.isEmpty)
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            'Este jugador aún no tiene fotos.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: photos
          .map(
            (post) => SizedBox(
              width: 220,
              height: 160,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImageViewerPage(imageUrl: post.imageUrl!),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF211E2E)),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _publicClips(List<PostModel> posts) {
    final clips = posts
        .where((post) => post.videoUrl?.isNotEmpty == true)
        .toList();
    if (clips.isEmpty)
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            'Este jugador aún no tiene clips.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    return Column(
      children: clips
          .map(
            (clip) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF171625),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E2A40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (clip.content.isNotEmpty) ...[
                    Text(
                      clip.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 360,
                      child: VideoPlayerWidget(url: clip.videoUrl!),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _aboutCard(Map<String, dynamic> profile) {
    final username = profile['username']?.toString() ?? 'Usuario';
    final bio = profile['bio']?.toString() ?? '';
    final status = profile['status']?.toString() ?? '';
    final location = profile['location']?.toString() ?? '';
    final platform = profile['platform']?.toString() ?? '';
    final role = profile['role']?.toString() ?? '';
    final favoriteGame = profile['favorite_game']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171625),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E2A40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                color: Color(0xFF9A78FF),
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'Acerca de $username',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              bio,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
          if (status.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.circle, size: 10, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Text(status, style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ],
          if (location.isNotEmpty ||
              platform.isNotEmpty ||
              role.isNotEmpty ||
              favoriteGame.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                if (location.isNotEmpty)
                  _publicInfoItem(Icons.location_on_outlined, location),
                if (platform.isNotEmpty)
                  _publicInfoItem(Icons.desktop_windows_outlined, platform),
                if (role.isNotEmpty)
                  _publicInfoItem(Icons.shield_outlined, role),
                if (favoriteGame.isNotEmpty)
                  _publicInfoItem(Icons.sports_esports_outlined, favoriteGame),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _publicInfoItem(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: const Color(0xFF9A78FF)),
      const SizedBox(width: 7),
      Text(text, style: const TextStyle(color: Colors.white60)),
    ],
  );

  Widget _wall(Map<String, dynamic> profile, List<PostModel> posts) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _aboutCard(profile),
      const SizedBox(height: 22),
      const Text(
        'Publicaciones',
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      if (posts.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Text(
              'Este usuario aún no tiene publicaciones.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        )
      else
        ...posts.asMap().entries.map(
          (entry) => PostCard(
            key: ValueKey(entry.value.id),
            post: entry.value,
            index: entry.key,
            videoController: _videoController,
          ),
        ),
    ],
  );
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.label, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 54,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: selected
            ? const Border(
                bottom: BorderSide(color: Color(0xFF8B5CF6), width: 3),
              )
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFFBDAAFF) : Colors.white60,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _PublicProfileData {
  const _PublicProfileData({
    required this.profile,
    required this.posts,
    required this.friendCount,
    required this.gameCount,
    required this.games,
  });

  final Map<String, dynamic> profile;
  final List<PostModel> posts;
  final int friendCount;
  final int gameCount;
  final List<UserGame> games;
}
