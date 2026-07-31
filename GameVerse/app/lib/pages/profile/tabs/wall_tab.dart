import 'package:flutter/material.dart';

import '../../../controllers/post_controller.dart';
import '../../../controllers/profile_controller.dart';

import '../../../widgets/post/post_create_box.dart';
import '../../../widgets/posts/post_list.dart';

class WallTab extends StatefulWidget {
  const WallTab({super.key});

  @override
  State<WallTab> createState() => _WallTabState();
}

class _WallTabState extends State<WallTab> {
  final PostController postController = PostController.instance;
  final ProfileController profileController = ProfileController.instance;

  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!loaded) {
      loaded = true;
      _loadPosts();
    }
  }

  Future<void> _loadPosts() async {
    if (profileController.userId == null) {
      await profileController.loadProfile();
    }

    if (profileController.userId != null) {
      await postController.loadUserPosts(profileController.userId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([postController, profileController]),
      builder: (context, _) {
        return Column(
          children: [
            const PostCreateBox(),

            const SizedBox(height: 20),

            Expanded(
              child: PostList(
                posts: postController.userPosts,
                loading: postController.isLoading,
                onRefresh: _loadPosts,
                emptyMessage: "Aún no tienes publicaciones.",
              ),
            ),
          ],
        );
      },
    );
  }
}
