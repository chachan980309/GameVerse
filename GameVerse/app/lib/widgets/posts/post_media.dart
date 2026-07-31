import 'package:flutter/material.dart';

import '../../controllers/video_feed_controller.dart';
import '../../models/post_model.dart';

import 'video_player_widget.dart';

class PostMedia extends StatelessWidget {
  final PostModel post;
  final int index;
  final VideoFeedController videoController;

  const PostMedia({
    super.key,
    required this.post,
    required this.index,
    required this.videoController,
  });

  @override
  Widget build(BuildContext context) {
    // ==========================
    // VIDEO
    // ==========================
    if (post.type == "video" &&
        post.videoUrl != null &&
        post.videoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 380,
          color: Colors.black,
          child: VideoPlayerWidget(url: post.videoUrl!),
        ),
      );
    }

    // ==========================
    // IMAGEN
    // ==========================
    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            post.imageUrl!,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return Container(
                height: 300,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 250,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 50,
                ),
              );
            },
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
