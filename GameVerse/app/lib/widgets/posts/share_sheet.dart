import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../services/friend_service.dart';
import '../../services/share_service.dart';

Future<void> showShareSheet(BuildContext context, PostModel post) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1927),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _ShareSheet(post: post),
    );

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.post});
  final PostModel post;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _service = ShareService();
  final _friends = FriendService();
  late Future<List<Map<String, dynamic>>> _friendList = _friends.getFriends();
  bool _sharing = false;

  Future<void> _shareToProfile() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await _service.shareToProfile(widget.post);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación compartida en tu perfil.')),
      );
    } catch (error) {
      debugPrint('Error al compartir en perfil: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo compartir la publicación.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareToFriend(Map<String, dynamic> friendship) async {
    final currentId = _friends.currentUserId;
    final senderId = friendship['sender_id']?.toString() ?? '';
    final receiverId = friendship['receiver_id']?.toString() ?? '';
    final friendId = senderId == currentId ? receiverId : senderId;
    if (friendId.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      await _service.shareByMessage(widget.post, friendId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación enviada por mensaje.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar la publicación.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Compartir publicación',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _choice(
            icon: Icons.dynamic_feed_rounded,
            title: 'Compartir en mi perfil',
            subtitle: 'La publicación aparecerá en tu muro e inicio.',
            onTap: _sharing ? null : _shareToProfile,
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Enviar por mensaje',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _friendList,
            builder: (context, snapshot) {
              final friends = snapshot.data ?? const <Map<String, dynamic>>[];
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              if (friends.isEmpty) {
                return const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No tienes amigos para enviarle esta publicación.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              return SizedBox(
                height: 136,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: friends.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final friendship = friends[index];
                    final currentId = _friends.currentUserId;
                    final profile = Map<String, dynamic>.from(
                      (friendship['sender_id']?.toString() == currentId
                                  ? friendship['receiver']
                                  : friendship['sender'])
                              as Map? ??
                          const {},
                    );
                    final name = profile['username']?.toString() ?? 'Usuario';
                    final avatar = profile['avatar_url']?.toString() ?? '';
                    return InkWell(
                      onTap: _sharing ? null : () => _shareToFriend(friendship),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 76,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFF6D35F5),
                              backgroundImage: avatar.isEmpty
                                  ? null
                                  : NetworkImage(avatar),
                              child: avatar.isEmpty
                                  ? Text(
                                      name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 7),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _choice({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF262137),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF6D35F5),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
