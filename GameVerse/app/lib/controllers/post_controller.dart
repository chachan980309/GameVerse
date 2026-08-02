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

  /// Feed principal
  List<PostModel> feedPosts = [];

  /// Publicaciones del perfil
  List<PostModel> userPosts = [];

  bool isLoading = false;

  /// Usuario cuyo muro está cargado actualmente
  String? _currentUserId;

  // ==========================
  // FEED
  // ==========================

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

  // ==========================
  // PERFIL
  // ==========================

  Future<void> loadUserPosts(String userId) async {
    _currentUserId = userId;

    isLoading = true;
    notifyListeners();

    try {
      userPosts = await _postService.getUserPosts(userId);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ==========================
  // CREAR PUBLICACIÓN
  // ==========================

  Future<void> createPost({
    required String content,
    String? imageUrl,
    String? videoUrl,
    String type = "text",
    String? sharedPostId,
  }) async {
    await _postService.createPost(
      content: content,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      type: type,
      sharedPostId: sharedPostId,
    );

    // Actualiza el feed
    await loadFeed();

    // Si el muro del perfil ya estaba cargado,
    // también se actualiza automáticamente.
    if (_currentUserId != null) {
      await loadUserPosts(_currentUserId!);
    }
  }
}
