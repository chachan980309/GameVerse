import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/post_service.dart';

class PostController extends ChangeNotifier {
  static final PostController instance = PostController._internal();

  factory PostController() => instance;

  PostController._internal() {
    loadFeed();
  }

  final PostService _postService = PostService();

  List<PostModel> feedPosts = [];

  bool isLoading = false;

  Future<void> loadFeed() async {
    isLoading = true;
    notifyListeners();

    try {
      feedPosts = await _postService.getFeedPosts();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserPosts(String userId) async {
    isLoading = true;
    notifyListeners();

    try {
      feedPosts = await _postService.getUserPosts(userId);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createPost({
    required String content,
    String? imageUrl,
    String? videoUrl,
    String type = "text",
  }) async {
    await _postService.createPost(
      content: content,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      type: type,
    );

    await loadFeed();
  }
}
