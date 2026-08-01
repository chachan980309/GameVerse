import 'package:flutter/material.dart';

import '../../../controllers/profile_controller.dart';
import '../../../controllers/video_feed_controller.dart';
import '../../../models/post_model.dart';
import '../../../services/post_service.dart';
import '../../../widgets/posts/post_card.dart';

class ClipsTab extends StatefulWidget {
  const ClipsTab({super.key});

  @override
  State<ClipsTab> createState() => _ClipsTabState();
}

class _ClipsTabState extends State<ClipsTab> {
  final _videoController = VideoFeedController();
  late Future<List<PostModel>> _clips = _loadClips();

  Future<List<PostModel>> _loadClips() async {
    final userId = ProfileController.instance.userId;
    if (userId == null) return [];
    final posts = await PostService().getUserPosts(userId);
    return posts.where((post) => post.videoUrl != null && post.videoUrl!.isNotEmpty).toList();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PostModel>>(
        future: _clips,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: Color(0xFF6D35F5)));
          final clips = snapshot.data ?? [];
          if (clips.isEmpty) return const Center(child: Text('Aún no tienes clips publicados.', style: TextStyle(color: Colors.white54)));
          return ListView.builder(
            padding: const EdgeInsets.all(28),
            itemCount: clips.length,
            itemBuilder: (context, index) => PostCard(post: clips[index], index: index, videoController: _videoController),
          );
        },
      );
}
