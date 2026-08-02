import 'package:flutter/material.dart';

import '../../../controllers/profile_controller.dart';
import '../../../models/post_model.dart';
import '../../image_viewer_page.dart';
import '../../../services/post_service.dart';
import '../../../widgets/posts/post_actions.dart';

class PhotosTab extends StatefulWidget {
  const PhotosTab({super.key});

  @override
  State<PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends State<PhotosTab> {
  late Future<List<PostModel>> _posts = _loadPhotos();

  Future<List<PostModel>> _loadPhotos() async {
    final userId = ProfileController.instance.userId;
    if (userId == null) return [];
    final posts = await PostService().getUserPosts(userId);
    return posts.where((post) => post.imageUrl != null && post.imageUrl!.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PostModel>>(
        future: _posts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: Color(0xFF6D35F5)));
          final photos = snapshot.data ?? [];
          if (photos.isEmpty) return const Center(child: Text('Aún no tienes fotos en tus publicaciones.', style: TextStyle(color: Colors.white54)));
          return GridView.builder(
            padding: const EdgeInsets.all(28),
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 330,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: .72,
            ),
            itemBuilder: (context, index) {
              final photo = photos[index];
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF302C43)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          PageRouteBuilder<void>(
                            pageBuilder: (_, __, ___) => ImageViewerPage(
                              imageUrl: photo.imageUrl!,
                              post: photo,
                            ),
                            transitionDuration: const Duration(milliseconds: 160),
                            reverseTransitionDuration: const Duration(milliseconds: 120),
                            transitionsBuilder: (_, animation, __, child) => FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          ),
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.network(
                            photo.imageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            cacheWidth: 660,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF211E2E)),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                      child: PostActions(post: photo),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
}
