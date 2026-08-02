import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/post_controller.dart';
import '../models/post_model.dart';
import 'direct_message_service.dart';

class ShareService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> shareToProfile(PostModel post) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Usuario no autenticado.');

    final original = post.sharedPost ?? post;
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
    final original = post.sharedPost ?? post;
    await DirectMessageService().sendMessage(
      receiverId,
      'Compartió una publicación de @${original.username}:\n${original.content}',
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
