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
  int _selectedFeed = 0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
    child: Column(
      children: [
        CreatePost(onPostCreated: postController.loadFeed),
        const SizedBox(height: 12),
        _feedTabs(),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedBuilder(
            animation: postController,
            builder: (context, _) => PostList(
              posts: postController.feedPosts,
              loading: postController.isLoading,
              onRefresh: postController.loadFeed,
              emptyMessage: 'Aún no hay publicaciones.',
            ),
          ),
        ),
      ],
    ),
  );

  Widget _feedTabs() => Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF171625),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF2E2A40)),
    ),
    child: Row(
      children: [
        _tab('Para ti', 0),
        _tab('Siguiendo', 1),
        _tab('Populares', 2),
        const Spacer(),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.tune_rounded, size: 17),
          label: const Text('Filtrar'),
          style: TextButton.styleFrom(foregroundColor: Colors.white54),
        ),
      ],
    ),
  );

  Widget _tab(String label, int index) {
    final selected = _selectedFeed == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedFeed = index),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: selected
              ? const Border(
                  bottom: BorderSide(color: Color(0xFF8B5CF6), width: 3),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFC5B4FF) : Colors.white60,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
