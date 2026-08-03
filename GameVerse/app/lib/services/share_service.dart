import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/post_controller.dart';
import '../models/post_model.dart';
import 'direct_message_service.dart';

class ShareService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> shareToProfile(PostModel post) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Usuario no autenticado.');

    final original = await _resolveOriginal(post);
    await PostController.instance.createPost(
      content: 'Compartió una publicación de @${original.username}',
      type: 'share',
      sharedPostId: original.id,
    );
    await _recordShare(original.id);

    try {
      await _notifyAuthor(original);
    } catch (_) {
      // La publicación ya fue creada: un fallo de notificación no la revierte.
    }
  }

  Future<void> shareByMessage(PostModel post, String receiverId) async {
    final original = await _resolveOriginal(post);
    await DirectMessageService().sendMessage(
      receiverId,
      'Compartió una publicación de @${original.username}',
      sharedPostId: original.id,
    );
    await _recordShare(original.id);
    try {
      await _notifyAuthor(original);
    } catch (_) {
      // El mensaje ya fue enviado aunque la notificación no pueda crearse.
    }
  }

  Future<int> getShareCount(String postId) async {
    try {
      final data = await _supabase
          .from('post_shares')
          .select('id')
          .eq('post_id', postId);
      return data.length;
    } catch (_) {
      return 0;
    }
  }

  /// A share must always reference the root post, never another share.
  /// This keeps the feed flat and displays the real original author/content.
  Future<PostModel> _resolveOriginal(PostModel post) async {
    var current = post.sharedPost ?? post;
    final visitedIds = <String>{post.id};

    for (var depth = 0; depth < 8; depth++) {
      final parentId = current.sharedPostId;
      if (parentId == null || !visitedIds.add(parentId)) return current;

      try {
        final row = await _supabase
            .from('posts')
            .select('*, profiles(username, avatar_url)')
            .eq('id', parentId)
            .maybeSingle();
        if (row == null) return current;
        current = PostModel.fromMap(Map<String, dynamic>.from(row));
      } catch (_) {
        return current;
      }
    }

    return current;
  }

  Future<void> _recordShare(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('post_shares').insert({
        'post_id': postId,
        'user_id': user.id,
      });
    } catch (_) {
      // Compatibilidad si la migración de conteos todavía no se aplicó.
    }
  }

  Future<void> _notifyAuthor(PostModel post) async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.id == post.userId) return;
    await _supabase.from('notifications').insert({
      'recipient_id': post.userId,
      'actor_id': user.id,
      'type': 'share',
      'post_id': post.id,
    });
  }
}
