import 'package:flutter/material.dart';

import '../controllers/post_controller.dart';

import '../widgets/forms/create_post.dart';
import '../widgets/posts/post_list.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final PostController postController = PostController.instance;

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
              return PostList(
                posts: postController.feedPosts,
                loading: postController.isLoading,
                onRefresh: postController.loadFeed,
                emptyMessage: "Aún no hay publicaciones.",
              );
            },
          ),
        ),
      ],
    );
  }
}
