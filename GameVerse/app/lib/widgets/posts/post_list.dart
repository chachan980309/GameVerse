import 'package:flutter/material.dart';

import '../../controllers/video_feed_controller.dart';
import '../../models/post_model.dart';

import 'post_card.dart';

class PostList extends StatefulWidget {
  final List<PostModel> posts;
  final Future<void> Function() onRefresh;
  final bool loading;
  final String emptyMessage;

  const PostList({
    super.key,
    required this.posts,
    required this.onRefresh,
    required this.loading,
    required this.emptyMessage,
  });

  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  final VideoFeedController videoController = VideoFeedController();

  @override
  void dispose() {
    videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff6438FF)),
      );
    }

    if (widget.posts.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xff6438FF),
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 150),
            Center(
              child: Text(
                widget.emptyMessage,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xff6438FF),
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: widget.posts.length,
        itemBuilder: (context, index) {
          return PostCard(
            post: widget.posts[index],
            index: index,
            videoController: videoController,
          );
        },
      ),
    );
  }
}
