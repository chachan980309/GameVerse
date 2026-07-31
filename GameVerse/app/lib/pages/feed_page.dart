import 'package:flutter/material.dart';

import '../controllers/post_controller.dart';
import '../controllers/video_feed_controller.dart';

import '../widgets/forms/create_post.dart';
import '../widgets/posts/post_card.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final PostController postController = PostController.instance;

  final VideoFeedController videoController = VideoFeedController();

  @override
  void dispose() {
    videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Inicio",
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        CreatePost(onPostCreated: () {}),

        const SizedBox(height: 20),

        Expanded(
          child: AnimatedBuilder(
            animation: postController,
            builder: (context, _) {
              if (postController.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xff6438FF)),
                );
              }

              if (postController.feedPosts.isEmpty) {
                return RefreshIndicator(
                  color: const Color(0xff6438FF),
                  onRefresh: postController.loadFeed,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 150),
                      Center(
                        child: Text(
                          "Aún no hay publicaciones.",
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: const Color(0xff6438FF),
                onRefresh: postController.loadFeed,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: postController.feedPosts.length,
                  itemBuilder: (context, index) {
                    return PostCard(
                      post: postController.feedPosts[index],
                      index: index,
                      videoController: videoController,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
