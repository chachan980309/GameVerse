import 'package:flutter/material.dart';

import '../../services/like_service.dart';
import '../../controllers/video_feed_controller.dart';

import 'video_player_widget.dart';
import '../../widgets/comments_sheet.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;

  final int index;

  final VideoFeedController videoController;

  const PostCard({
    super.key,

    required this.post,

    required this.index,

    required this.videoController,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final LikeService likeService = LikeService();

  bool liked = false;

  int likes = 0;

  bool loadingLike = false;

  bool showHeart = false;

  double heartScale = 0;

  @override
  void initState() {
    super.initState();

    loadPostData();
  }

  Future<void> loadPostData() async {
    final total = await likeService.getLikes(widget.post['id']);

    final userLiked = await likeService.hasLiked(
      postId: widget.post['id'],
      username: "Gio",
    );

    if (!mounted) return;

    setState(() {
      likes = total;

      liked = userLiked;
    });
  }

  Future<void> toggleLike() async {
    if (loadingLike) return;

    setState(() {
      loadingLike = true;
    });

    try {
      if (liked) {
        await likeService.removeLike(
          postId: widget.post['id'],

          username: "Gio",
        );

        if (!mounted) return;

        setState(() {
          liked = false;

          likes--;
        });
      } else {
        await likeService.addLike(postId: widget.post['id'], username: "Gio");

        if (!mounted) return;

        setState(() {
          liked = true;

          likes++;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    if (!mounted) return;

    setState(() {
      loadingLike = false;
    });
  }

  void doubleTapLike() {
    if (!liked) {
      toggleLike();
    }

    setState(() {
      showHeart = true;
      heartScale = 0;
    });

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          heartScale = 1;
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          showHeart = false;
        });
      }
    });
  }

  Widget buildMedia() {
    // VIDEO

    if (widget.post['type'] == "video" &&
        widget.post['video'] != null &&
        widget.post['video'].toString().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),

        child: Container(
          width: double.infinity,

          height: 380,

          color: Colors.black,

          child: GestureDetector(
            child: VideoPlayerWidget(url: widget.post['video']),
          ),
        ),
      );
    }

    // IMAGEN

    if (widget.post['image'] != null &&
        widget.post['image'].toString().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),

        child: Container(
          width: double.infinity,

          constraints: const BoxConstraints(maxHeight: 500),

          color: Colors.black,

          child: GestureDetector(
            onDoubleTap: toggleLike,
            child: GestureDetector(
              onDoubleTap: doubleTapLike,

              child: Stack(
                alignment: Alignment.center,

                children: [
                  Image.network(widget.post['image'], fit: BoxFit.contain),

                  if (showHeart)
                    AnimatedScale(
                      scale: heartScale,

                      duration: const Duration(milliseconds: 250),

                      curve: Curves.elasticOut,

                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 120,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: const Color(0xff211D2E),

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,

                backgroundColor: Color(0xff6438FF),

                child: Icon(Icons.person, color: Colors.white),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      widget.post['username'] ?? "Gio",

                      style: const TextStyle(
                        color: Colors.white,

                        fontWeight: FontWeight.bold,

                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 3),

                    const Text(
                      "Hace unos momentos",

                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.more_horiz, color: Colors.white54),
            ],
          ),

          const SizedBox(height: 18),

          if (widget.post['content'] != null &&
              widget.post['content'].toString().isNotEmpty)
            Text(
              widget.post['content'].toString(),

              style: const TextStyle(
                color: Colors.white,

                fontSize: 16,

                height: 1.4,
              ),
            ),

          const SizedBox(height: 15),

          buildMedia(),

          const SizedBox(height: 15),

          Row(
            children: [
              InkWell(
                onTap: toggleLike,

                child: Row(
                  children: [
                    Icon(
                      liked ? Icons.favorite : Icons.favorite_border,

                      color: liked ? Colors.redAccent : Colors.white54,

                      size: 20,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      "$likes",

                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 25),

              InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) {
                      return CommentsSheet(postId: widget.post['id']);
                    },
                  );
                },

                child: const Icon(
                  Icons.chat_bubble_outline,

                  color: Colors.white54,

                  size: 19,
                ),
              ),

              const SizedBox(width: 6),

              Text(
                "${widget.post['comments'] ?? 0}",

                style: const TextStyle(color: Colors.white70),
              ),

              const Spacer(),

              const Text("Comentar", style: TextStyle(color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }
}
