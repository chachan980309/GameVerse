import 'package:supabase_flutter/supabase_flutter.dart';

class LikeService {
  final SupabaseClient supabase = Supabase.instance.client;

  // CREAR LIKE

  Future<void> addLike({
    required String postId,

    required String username,
  }) async {
    await supabase.from('post_likes').insert({
      'post_id': postId,

      'username': username,
    });
  }

  // ELIMINAR LIKE

  Future<void> removeLike({
    required String postId,

    required String username,
  }) async {
    await supabase
        .from('post_likes')
        .delete()
        .eq('post_id', postId)
        .eq('username', username);
  }

  // CONTAR LIKES

  Future<int> getLikes(String postId) async {
    final data = await supabase
        .from('post_likes')
        .select('id')
        .eq('post_id', postId);

    return data.length;
  }

  // SABER SI ESTE USUARIO YA DIO LIKE

  Future<bool> hasLiked({
    required String postId,

    required String username,
  }) async {
    final data = await supabase
        .from('post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('username', username);

    return data.isNotEmpty;
  }
}
