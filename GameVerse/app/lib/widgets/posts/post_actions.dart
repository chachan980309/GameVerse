import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../services/like_service.dart';
import '../comments_sheet.dart';

class PostActions extends StatefulWidget {
  final PostModel post;

  const PostActions({super.key, required this.post});

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  final LikeService likeService = LikeService();

  bool liked = false;
  bool loading = false;
  int likes = 0;

  @override
  void initState() {
    super.initState();
    loadLikes();
  }

  Future<void> loadLikes() async {
    try {
      final total = await likeService.getLikes(widget.post.id);
      final userLiked = await likeService.hasLiked(postId: widget.post.id);

      if (!mounted) return;

      setState(() {
        likes = total;
        liked = userLiked;
      });
    } catch (_) {}
  }

  Future<void> toggleLike() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      if (liked) {
        await likeService.removeLike(postId: widget.post.id);

        if (!mounted) return;

        setState(() {
          liked = false;
          likes--;
        });
      } else {
        await likeService.addLike(postId: widget.post.id);

        if (!mounted) return;

        setState(() {
          liked = true;
          likes++;
        });
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              "$likes Me gusta",
              style: const TextStyle(color: Colors.white70),
            ),

            const Spacer(),

            const Text("Comentarios", style: TextStyle(color: Colors.white54)),
          ],
        ),

        const SizedBox(height: 12),

        const Divider(color: Colors.white12, height: 1),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: toggleLike,
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? Colors.redAccent : Colors.white70,
                ),
                label: Text(
                  "Me gusta",
                  style: TextStyle(
                    color: liked ? Colors.redAccent : Colors.white70,
                  ),
                ),
              ),
            ),

            Expanded(
              child: TextButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CommentsSheet(postId: widget.post.id),
                  );
                },
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white70,
                ),
                label: const Text(
                  "Comentar",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),

            Expanded(
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.share_outlined, color: Colors.white70),
                label: const Text(
                  "Compartir",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
