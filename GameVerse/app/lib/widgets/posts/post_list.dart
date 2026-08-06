import 'package:flutter/material.dart';

import '../../controllers/video_feed_controller.dart';
import '../../models/post_model.dart';

import 'post_card.dart';

class PostList extends StatefulWidget {
  final List<PostModel> posts;
  final Future<void> Function() onRefresh;
  final bool loading;
  final String emptyMessage;
  final String? focusPostId;
  final ScrollController? scrollController;

  const PostList({
    super.key,
    required this.posts,
    required this.onRefresh,
    required this.loading,
    required this.emptyMessage,
    this.focusPostId,
    this.scrollController,
  });

  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  final VideoFeedController videoController = VideoFeedController();
  final _postKeys = <String, GlobalKey>{};
  String? _lastFocusedPostId;

  @override
  void initState() {
    super.initState();
    _lastFocusedPostId = widget.focusPostId;
    if (widget.focusPostId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusPost());
    }
  }

  @override
  void didUpdateWidget(covariant PostList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusPostId != null &&
        widget.focusPostId != _lastFocusedPostId) {
      _lastFocusedPostId = widget.focusPostId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusPost());
    }
  }

  void _focusPost() {
    final key = _postKeys[widget.focusPostId];
    final targetContext = key?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: .12,
      );
    }
  }

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
          controller: widget.scrollController,
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
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: widget.posts.length,
        itemBuilder: (context, index) {
          final post = widget.posts[index];
          final isFocused = post.id == widget.focusPostId;
          final key = isFocused 
              ? _postKeys.putIfAbsent(post.id, GlobalKey.new)
              : ValueKey(post.id);

          return PostCard(
            key: key,
            post: post,
            index: index,
            videoController: videoController,
          );
        },
      ),
    );
  }
}
