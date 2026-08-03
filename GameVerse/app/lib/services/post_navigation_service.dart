import 'package:flutter/foundation.dart';

/// Canal de navegación ligero para abrir una publicación desde cualquier
/// parte de la aplicación, incluidos los chats.
class PostNavigationService extends ChangeNotifier {
  PostNavigationService._();

  static final PostNavigationService instance = PostNavigationService._();

  String? _postId;

  String? get postId => _postId;

  void openPost(String postId) {
    _postId = postId;
    notifyListeners();
  }
}
