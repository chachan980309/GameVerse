import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/profile_controller.dart';

class CommentService {
  final SupabaseClient supabase = Supabase.instance.client;

  // CREAR COMENTARIO

  Future<void> addComment({
    required String postId,

    required String content,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión para comentar.');

    await supabase.from('comments').insert({
      'post_id': postId,
      'user_id': user.id,
      'content': content,
    });
    await ProfileController.instance.loadProfile();
  }

  // OBTENER COMENTARIOS

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final data = await supabase
          .from('comments')
          .select('*, profiles!comments_user_id_fkey(id, username, avatar_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      // Compatibilidad temporal con comentarios antiguos antes de aplicar SQL.
      final data = await supabase
          .from('comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    }
  }

  Future<int> getCommentCount(String postId) async {
    final data = await supabase
        .from('comments')
        .select('id')
        .eq('post_id', postId);
    return data.length;
  }

  // ELIMINAR COMENTARIO

  Future<void> deleteComment(String id) async {
    await supabase.from('comments').delete().eq('id', id);
  }
}
