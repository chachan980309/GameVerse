import 'package:supabase_flutter/supabase_flutter.dart';

class CommentService {
  final SupabaseClient supabase = Supabase.instance.client;

  // CREAR COMENTARIO

  Future<void> addComment({
    required String postId,

    required String username,

    required String content,
  }) async {
    await supabase.from('comments').insert({
      'post_id': postId,

      'username': username,

      'content': content,
    });
  }

  // OBTENER COMENTARIOS

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final data = await supabase
        .from('comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data);
  }

  // ELIMINAR COMENTARIO

  Future<void> deleteComment(String id) async {
    await supabase.from('comments').delete().eq('id', id);
  }
}
