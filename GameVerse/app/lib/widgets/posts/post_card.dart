import 'package:flutter/material.dart';

import '../../controllers/video_feed_controller.dart';
import '../../models/post_model.dart';

import 'post_actions.dart';
import 'post_header.dart';
import 'post_media.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final int index;
  final VideoFeedController videoController;

  const PostCard({
    super.key,
    required this.post,
    required this.index,
    required this.videoController,
  });

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
          /// HEADER
          PostHeader(post: post),

          /// CONTENIDO
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              post.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],

          /// MEDIA
          if ((post.imageUrl != null && post.imageUrl!.isNotEmpty) ||
              (post.videoUrl != null && post.videoUrl!.isNotEmpty)) ...[
            const SizedBox(height: 16),
            PostMedia(
              post: post,
              index: index,
              videoController: videoController,
            ),
          ],

          const SizedBox(height: 16),

          /// ACCIONES
          PostActions(post: post),
        ],
      ),
    );
  }
}
