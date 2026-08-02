import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/post_model.dart';
import '../../services/comment_service.dart';
import '../../services/like_service.dart';
import '../comments_sheet.dart';
import 'share_sheet.dart';

class PostActions extends StatefulWidget {
  const PostActions({super.key, required this.post});

  final PostModel post;

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  static final Map<String, _InteractionData> _cache = {};

  final LikeService likeService = LikeService();
  final CommentService commentService = CommentService();
  RealtimeChannel? _channel;
  bool liked = false;
  bool loading = false;
  bool _hasData = false;
  int likes = 0;
  int comments = 0;

  @override
  void initState() {
    super.initState();
    final cached = _cache[widget.post.id];
    if (cached != null) {
      liked = cached.liked;
      likes = cached.likes;
      comments = cached.comments;
      _hasData = true;
    }
    _refreshInteractions();
    _listenToInteractions();
  }

  @override
  void didUpdateWidget(covariant PostActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id == widget.post.id) return;
    _stopListening();
    final cached = _cache[widget.post.id];
    setState(() {
      liked = cached?.liked ?? false;
      likes = cached?.likes ?? 0;
      comments = cached?.comments ?? 0;
      _hasData = cached != null;
    });
    _refreshInteractions();
    _listenToInteractions();
  }

  Future<void> _refreshInteractions() async {
    try {
      final values = await Future.wait<dynamic>([
        likeService.getLikes(widget.post.id),
        likeService.hasLiked(postId: widget.post.id),
        commentService.getCommentCount(widget.post.id),
      ]);
      if (!mounted) return;
      final updated = _InteractionData(
        likes: values[0] as int,
        liked: values[1] as bool,
        comments: values[2] as int,
      );
      _cache[widget.post.id] = updated;
      setState(() {
        likes = updated.likes;
        liked = updated.liked;
        comments = updated.comments;
        _hasData = true;
      });
    } catch (_) {
      // Keep the last known value instead of briefly showing zero.
    }
  }

  void _listenToInteractions() {
    _channel = Supabase.instance.client
        .channel('post-interactions-${widget.post.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'post_likes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: widget.post.id,
          ),
          callback: (_) => _refreshInteractions(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: widget.post.id,
          ),
          callback: (_) => _refreshInteractions(),
        )
        .subscribe();
  }

  Future<void> _stopListening() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await Supabase.instance.client.removeChannel(channel);
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  Future<void> toggleLike() async {
    if (loading) return;
    final previous = _InteractionData(
      likes: likes,
      liked: liked,
      comments: comments,
    );
    setState(() {
      loading = true;
      liked = !liked;
      likes = liked ? likes + 1 : (likes - 1).clamp(0, 1 << 31).toInt();
      _hasData = true;
    });
    _cache[widget.post.id] = _InteractionData(
      likes: likes,
      liked: liked,
      comments: comments,
    );

    try {
      if (liked) {
        await likeService.addLike(postId: widget.post.id);
      } else {
        await likeService.removeLike(postId: widget.post.id);
      }
      await _refreshInteractions();
    } catch (_) {
      if (mounted) {
        setState(() {
          liked = previous.liked;
          likes = previous.likes;
          comments = previous.comments;
        });
        _cache[widget.post.id] = previous;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar Me gusta.')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Icon(
            Icons.favorite,
            color: liked ? Colors.redAccent : Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 5),
          Text(
            _hasData ? '$likes Me gusta' : 'Cargando...',
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          Text(
            _hasData
                ? '$comments ${comments == 1 ? 'comentario' : 'comentarios'}'
                : '',
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Divider(color: Colors.white12, height: 1),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: loading ? null : toggleLike,
              icon: Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                color: liked ? Colors.redAccent : Colors.white70,
              ),
              label: Text(
                'Me gusta',
                style: TextStyle(
                  color: liked ? Colors.redAccent : Colors.white70,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CommentsSheet(
                  postId: widget.post.id,
                  onCommentAdded: _refreshInteractions,
                ),
              ),
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white70,
              ),
              label: const Text(
                'Comentar',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: () => showShareSheet(context, widget.post),
              icon: const Icon(Icons.share_outlined, color: Colors.white70),
              label: const Text(
                'Compartir',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _InteractionData {
  const _InteractionData({
    required this.likes,
    required this.liked,
    required this.comments,
  });
  final int likes;
  final bool liked;
  final int comments;
}
