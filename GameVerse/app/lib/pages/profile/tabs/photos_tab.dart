import 'package:flutter/material.dart';

import '../../../controllers/profile_controller.dart';
import '../../../models/post_model.dart';
import '../../image_viewer_page.dart';
import '../../../services/post_service.dart';

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
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 280, mainAxisSpacing: 14, crossAxisSpacing: 14),
            itemBuilder: (context, index) => InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerPage(imageUrl: photos[index].imageUrl!))),
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Hero(
                  tag: photos[index].imageUrl!,
                  child: Image.network(photos[index].imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF211E2E))),
                ),
              ),
            ),
          );
        },
      );
}
