import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/post_model.dart';
import '../../services/friend_service.dart';
import '../../services/post_service.dart';
import '../../services/user_games_service.dart';

class FeedRightPanel extends StatefulWidget {
  const FeedRightPanel({super.key, this.onOpenChat});

  final void Function(Map<String, dynamic> profile)? onOpenChat;

  @override
  State<FeedRightPanel> createState() => _FeedRightPanelState();
}

class _FeedRightPanelState extends State<FeedRightPanel> {
  Timer? _rotationTimer;
  Timer? _refreshTimer;
  int _activeCard = 0;
  bool _loading = true;
  List<_FriendInfo> _friends = const [];
  List<PostModel> _friendPosts = const [];
  List<_Trend> _trends = const [];
  int _postsToday = 0;
  int _commentsToday = 0;
  int _gamesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _rotationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() => _activeCard = (_activeCard + 1) % 3);
    });
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadData(showLoading: false),
    );
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (showLoading && mounted) setState(() => _loading = true);

    try {
      final friendRows = await FriendService().getAcceptedFriends();
      final friends = friendRows
          .map((row) {
            final isSender = row['sender_id'] == user.id;
            final raw = isSender ? row['receiver'] : row['sender'];
            return _FriendInfo.fromMap(
              Map<String, dynamic>.from(raw ?? const {}),
            );
          })
          .where((friend) => friend.id.isNotEmpty)
          .toList();

      final posts = await PostService().getFeedPosts();
      final friendIds = friends.map((friend) => friend.id).toSet();
      final friendPosts = posts
          .where((post) => friendIds.contains(post.userId))
          .take(3)
          .toList();
      final postsToday = posts
          .where((post) => post.userId == user.id && _isToday(post.createdAt))
          .length;

      final comments = await Supabase.instance.client
          .from('comments')
          .select('created_at')
          .eq('user_id', user.id);
      final commentsToday = comments.where((row) {
        final createdAt = row['created_at'];
        return createdAt != null &&
            _isToday(DateTime.parse(createdAt.toString()));
      }).length;

      final myGames = await UserGamesService().getMyGames();
      List<_Trend> trends = const [];
      try {
        final gameRows = await Supabase.instance.client
            .from('user_games')
            .select('game_name');
        final counts = <String, int>{};
        for (final row in gameRows) {
          final name = row['game_name']?.toString().trim() ?? '';
          if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
        }
        final entries = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        trends = entries
            .take(4)
            .map((entry) => _Trend(entry.key, entry.value))
            .toList();
      } catch (_) {
        // If RLS only allows a user's own games, still show real personal data.
        trends = myGames
            .map((game) => _Trend(game.gameName, 1))
            .take(4)
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _friends = friends;
        _friendPosts = friendPosts;
        _postsToday = postsToday;
        _commentsToday = commentsToday;
        _gamesCount = myGames.length;
        _trends = trends;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isToday(DateTime value) {
    final date = value.toLocal();
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) => Container(
    color: const Color.fromRGBO(10, 9, 18, 0.88),
    padding: const EdgeInsets.all(14),
    child: ListView(
      children: [
        _card(_friendsCard(context)),
        const SizedBox(height: 12),
        _smartCard(),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Próximamente podrás crear grupos.'),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear grupo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6D35F5),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _friendsCard(BuildContext context) {
    final online = _friends.where((friend) => friend.isOnline).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Amigos conectados', 'Ver todos'),
        Text(
          _loading ? 'Actualizando...' : '$online conectados',
          style: const TextStyle(color: Color(0xFF48E69A), fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (!_loading && _friends.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aún no tienes amigos agregados.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ..._friends
            .take(4)
            .map(
              (friend) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF3D2B6C),
                          backgroundImage: friend.avatarUrl.isNotEmpty
                              ? NetworkImage(friend.avatarUrl)
                              : null,
                          child: friend.avatarUrl.isEmpty
                              ? Text(
                                  friend.initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: CircleAvatar(
                            radius: 5,
                            backgroundColor: friend.isOnline
                                ? const Color(0xFF48E69A)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            friend.gameOrStatus,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final callback = widget.onOpenChat;
                        if (callback != null) {
                          callback({
                            'id': friend.id,
                            'username': friend.name,
                            'avatar_url': friend.avatarUrl,
                            'is_online': friend.isOnline,
                          });
                        }
                      },
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Color(0xff8B4DFF),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _smartCard() {
    final cards = [_activity(), _mission(), _trendsCard()];
    return Container(
      height: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171625),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D2940)),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFAF8CFF),
                size: 15,
              ),
              SizedBox(width: 6),
              Text(
                'Tarjeta inteligente',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Spacer(),
              Icon(Icons.sync_rounded, color: Colors.white54, size: 15),
              SizedBox(width: 4),
              Text(
                '15 s',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: ValueKey(_activeCard),
                child: cards[_activeCard],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => GestureDetector(
                onTap: () => setState(() => _activeCard = index),
                child: Container(
                  width: _activeCard == index ? 13 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _activeCard == index
                        ? const Color(0xFF9A78FF)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activity() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title('Actividad de amigos', 'Ver todo'),
      const SizedBox(height: 10),
      if (_loading)
        const Expanded(
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      if (!_loading && _friendPosts.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 28),
          child: Center(
            child: Text(
              'Aún no hay publicaciones recientes.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ),
      ..._friendPosts.map(
        (post) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF29213F),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.article_outlined,
                  color: Color(0xFFAF8CFF),
                  size: 17,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${post.username} publicó\n${post.content.isEmpty ? 'contenido nuevo' : post.content}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ),
              Text(
                _timeAgo(post.createdAt),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _mission() {
    final posted = _postsToday > 0;
    final commented = _commentsToday >= 3;
    final addedGame = _gamesCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Misión del día', 'Datos reales'),
        const SizedBox(height: 10),
        _missionRow('Publica un post', posted ? '✓' : '0/1', posted),
        _missionRow(
          'Comenta 3 publicaciones',
          '${_commentsToday.clamp(0, 3)}/3',
          commented,
        ),
        _missionRow(
          'Añade un juego a tu perfil',
          addedGame ? '✓' : '0/1',
          addedGame,
        ),
        const Divider(color: Color(0xFF2D2940)),
        Text(
          'Recompensa:  ⚡ ${posted && commented && addedGame ? '150 XP lista' : '150 XP'}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _missionRow(String label, String progress, bool done) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF211E2E),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: done ? const Color(0xFF48E69A) : Colors.white38,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        Text(
          progress,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    ),
  );

  Widget _trendsCard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title('Tendencias', 'Ver más'),
      const SizedBox(height: 9),
      if (_loading)
        const Expanded(
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      if (!_loading && _trends.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 28),
          child: Center(
            child: Text(
              'Aún no hay juegos registrados.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ),
      ..._trends.map(
        (trend) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              const Icon(
                Icons.sports_esports_rounded,
                color: Color(0xFFAF8CFF),
                size: 17,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  trend.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${trend.players} ${trend.players == 1 ? 'jugador' : 'jugadores'}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  String _timeAgo(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) return 'Ahora';
    if (difference.inHours < 1) return '${difference.inMinutes} min';
    if (difference.inDays < 1) return '${difference.inHours} h';
    return '${difference.inDays} d';
  }

  Widget _title(String text, String action) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Text(
        action,
        style: const TextStyle(color: Color(0xFFAF8CFF), fontSize: 11),
      ),
    ],
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF171625),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF2D2940)),
    ),
    child: child,
  );
}

class _FriendInfo {
  const _FriendInfo({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.isOnline,
    required this.favoriteGame,
    required this.status,
  });
  factory _FriendInfo.fromMap(Map<String, dynamic> map) => _FriendInfo(
    id: map['id']?.toString() ?? '',
    name: map['username']?.toString() ?? 'Usuario',
    avatarUrl: map['avatar_url']?.toString() ?? '',
    isOnline: map['is_online'] == true,
    favoriteGame: map['favorite_game']?.toString() ?? '',
    status: map['status']?.toString() ?? '',
  );
  final String id, name, avatarUrl, favoriteGame, status;
  final bool isOnline;

  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  String get gameOrStatus => favoriteGame.isNotEmpty
      ? favoriteGame
      : (status.isNotEmpty ? status : 'Sin juego registrado');
}

class _Trend {
  const _Trend(this.name, this.players);
  final String name;
  final int players;
}
