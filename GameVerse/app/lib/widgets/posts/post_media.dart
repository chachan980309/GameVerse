import 'dart:async';
import 'dart:math' as math;

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

  static final Map<String, Future<ImageInfo>> _mediaImageSizeCache = {};

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
        child: VideoPlayerWidget(
          key: ValueKey('video-${post.id}'),
          url: post.videoUrl!,
          videoId: post.id,
          videoController: videoController,
          thumbnailUrl: post.thumbnailUrl,
          duration: post.duration,
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
            if (snapshot.hasData) {
              final image = snapshot.data!.image;
              final ratio = image.width / image.height;

              return LayoutBuilder(
                builder: (context, constraints) {
                  // La imagen conserva siempre su proporción. Los retratos no
                  // estiran la tarjeta completa ni dejan bandas laterales.
                  const maxMediaHeight = 520.0;
                  final width = math.min(
                    constraints.maxWidth,
                    maxMediaHeight * ratio,
                  );
                  final height = width / ratio;

                  return Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ImageViewerPage(imageUrl: post.imageUrl!),
                            ),
                          );
                        },
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: Image.network(
                            post.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
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
                    ),
                  );
                },
              );
            }

            return const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<ImageInfo> _loadImage(String url) {
    return _mediaImageSizeCache.putIfAbsent(url, () {
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
    });
  }
}
