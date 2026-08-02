import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/post_model.dart';
import '../../services/comment_service.dart';
import '../../services/like_service.dart';
import '../../services/share_service.dart';
import '../comments_sheet.dart';
import 'share_sheet.dart';

class PostActions extends StatefulWidget {
  const PostActions({
    super.key,
    required this.post,
    this.onCommentChanged,
  });

  final PostModel post;
  final VoidCallback? onCommentChanged;

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  static final Map<String, _InteractionData> _cache = {};

  final LikeService likeService = LikeService();
  final CommentService commentService = CommentService();
  final ShareService shareService = ShareService();
  RealtimeChannel? _channel;
  bool liked = false;
  bool loading = false;
  bool _hasData = false;
  int likes = 0;
  int comments = 0;
  int shares = 0;

  @override
  void initState() {
    super.initState();
    final cached = _cache[widget.post.id];
    if (cached != null) {
      liked = cached.liked;
      likes = cached.likes;
      comments = cached.comments;
      shares = cached.shares;
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
      shares = cached?.shares ?? 0;
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
        shareService.getShareCount(widget.post.id),
      ]);
      if (!mounted) return;
      final updated = _InteractionData(
        likes: values[0] as int,
        liked: values[1] as bool,
        comments: values[2] as int,
        shares: values[3] as int,
      );
      _cache[widget.post.id] = updated;
      setState(() {
        likes = updated.likes;
        liked = updated.liked;
        comments = updated.comments;
        shares = updated.shares;
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
          table: 'post_shares',
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
      shares: shares,
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
      shares: shares,
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
          shares = previous.shares;
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 420;
      final interactionColor = liked ? Colors.redAccent : Colors.white70;

      return Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: compact ? 7 : 14,
              runSpacing: 4,
              children: [
                _counter(
                  icon: Icons.favorite,
                  label: _hasData ? '$likes' : '…',
                  color: liked ? Colors.redAccent : Colors.white54,
                ),
                _counter(
                  icon: Icons.chat_bubble_outline,
                  label: _hasData ? '$comments' : '…',
                ),
                _counter(
                  icon: Icons.share_outlined,
                  label: _hasData ? '$shares' : '…',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _action(
                  compact: compact,
                  tooltip: 'Me gusta',
                  onPressed: loading ? null : toggleLike,
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  label: 'Me gusta',
                  color: interactionColor,
                ),
              ),
              Expanded(
                child: _action(
                  compact: compact,
                  tooltip: 'Comentar',
                  onPressed: _openComments,
                  icon: Icons.chat_bubble_outline,
                  label: 'Comentar',
                ),
              ),
              Expanded(
                child: _action(
                  compact: compact,
                  tooltip: 'Compartir',
                  onPressed: () => showShareSheet(
                    context,
                    widget.post,
                    onShared: _refreshInteractions,
                  ),
                  icon: Icons.share_outlined,
                  label: 'Compartir',
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  Future<void> _openComments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        postId: widget.post.id,
        onCommentAdded: () {
          _refreshInteractions();
          widget.onCommentChanged?.call();
        },
      ),
    );
  }

  Widget _counter({
    required IconData icon,
    required String label,
    Color color = Colors.white54,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 12)),
    ],
  );

  Widget _action({
    required bool compact,
    required String tooltip,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Color color = Colors.white70,
  }) {
    if (compact) {
      return Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color, size: 20),
        ),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: 19),
      label: Text(label, style: TextStyle(color: color)),
    );
  }
}

class _InteractionData {
  const _InteractionData({
    required this.likes,
    required this.liked,
    required this.comments,
    required this.shares,
  });
  final int likes;
  final bool liked;
  final int comments;
  final int shares;
}
