import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/post_controller.dart';
import '../models/post_model.dart';
import 'direct_message_service.dart';

class ShareService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> shareToProfile(PostModel post) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado.');

    // This is intentionally the same path used by the normal post composer.
    // It uses the existing posts schema and refreshes the feed immediately.
    await PostController.instance.createPost(
      content:
          'Compartió una publicación de @${post.username}\n\n${post.content}',
      imageUrl: post.imageUrl,
      videoUrl: post.videoUrl,
      type: post.videoUrl?.isNotEmpty == true
          ? 'video'
          : (post.imageUrl?.isNotEmpty == true ? 'image' : 'text'),
    );

    try {
      await _notifyAuthor(post);
    } catch (_) {
      // The share is already published; a notification failure must not undo it.
    }
  }

  Future<void> shareByMessage(PostModel post, String receiverId) async {
    await DirectMessageService().sendMessage(
      receiverId,
      'Compartió una publicación de @${post.username}:\n${post.content}',
    );
    try {
      await _notifyAuthor(post);
    } catch (_) {
      // Sending the message is the primary action.
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
