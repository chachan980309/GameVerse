import 'package:flutter/material.dart';

import '../../controllers/video_feed_controller.dart';
import '../../models/post_model.dart';

import 'post_actions.dart';
import 'post_header.dart';
import 'post_media.dart';
import '../mention_text.dart';

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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF302C43)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          PostHeader(post: post),

          /// CONTENIDO
          // En un compartido, el contenido real vive exclusivamente dentro de
          // la tarjeta original para mantener ambas publicaciones separadas.
          if (post.content.isNotEmpty && !post.isSharedPost) ...[
            const SizedBox(height: 16),
            MentionText(
              text: post.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],

          // El compartido se presenta como una publicación independiente,
          // no mezclado con la publicación de quien la compartió.
          if (post.sharedPost != null) ...[
            const SizedBox(height: 14),
            _SharedPostCard(
              post: post.sharedPost!,
              index: index,
              videoController: videoController,
            ),
          ],

          // Old shares did not retain the original post id. Keep their text
          // separated visually instead of repeating it in the outer post.
          if (post.isSharedPost && post.sharedPost == null) ...[
            const SizedBox(height: 14),
            _LegacySharedPostCard(content: post.content),
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

class _LegacySharedPostCard extends StatelessWidget {
  const _LegacySharedPostCard({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF151321),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF6237B8)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.article_outlined, color: Color(0xFF9A78FF)),
        const SizedBox(width: 10),
        Expanded(
          child: MentionText(
            text: content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SharedPostCard extends StatelessWidget {
  const _SharedPostCard({
    required this.post,
    required this.index,
    required this.videoController,
  });

  final PostModel post;
  final int index;
  final VideoFeedController videoController;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF151321),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF6237B8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PostHeader(post: post),
        if (post.content.isNotEmpty) ...[
          const SizedBox(height: 12),
          MentionText(
            text: post.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
        if ((post.imageUrl?.isNotEmpty ?? false) ||
            (post.videoUrl?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: PostMedia(
              post: post,
              index: index,
              videoController: videoController,
            ),
          ),
        ],
      ],
    ),
  );
}
