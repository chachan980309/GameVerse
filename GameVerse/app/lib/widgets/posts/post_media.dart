import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/video_feed_controller.dart';
import '../../models/post_model.dart';

import '../../pages/image_viewer_page.dart';
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
          height: 420,
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
        child: FutureBuilder<ImageInfo>(
          future: _loadImage(post.imageUrl!),
          builder: (context, snapshot) {
            double height = 420;

            if (snapshot.hasData) {
              final image = snapshot.data!.image;
              final ratio = image.width / image.height;

              if (ratio > 1.35) {
                // Horizontal
                height = 320;
              } else if (ratio < 0.8) {
                // Vertical
                height = 650;
              } else {
                // Cuadrada
                height = 450;
              }
            }

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImageViewerPage(imageUrl: post.imageUrl!),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: height,
                  color: Colors.transparent,
                  child: Image.network(
                    post.imageUrl!,
                    width: double.infinity,
                    height: height,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 60,
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<ImageInfo> _loadImage(String url) {
    final provider = NetworkImage(url);

    final completer = Completer<ImageInfo>();

    final stream = provider.resolve(const ImageConfiguration());

    late ImageStreamListener listener;

    listener = ImageStreamListener((info, _) {
      completer.complete(info);
      stream.removeListener(listener);
    });

    stream.addListener(listener);

    return completer.future;
  }
}
