import 'package:supabase_flutter/supabase_flutter.dart';

class LikeService {
  final SupabaseClient supabase = Supabase.instance.client;

  User get _user => supabase.auth.currentUser!;

  // ==========================
  // DAR LIKE
  // ==========================

  Future<void> addLike({required String postId}) async {
    await supabase.from('post_likes').insert({
      'post_id': postId,
      'user_id': _user.id,
    });
  }

  // ==========================
  // QUITAR LIKE
  // ==========================

  Future<void> removeLike({required String postId}) async {
    await supabase
        .from('post_likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', _user.id);
  }

  // ==========================
  // CONTAR LIKES
  // ==========================

  Future<int> getLikes(String postId) async {
    final data = await supabase
        .from('post_likes')
        .select('id')
        .eq('post_id', postId);

    return data.length;
  }

  // ==========================
  // ¿YA DIO LIKE?
  // ==========================

  Future<bool> hasLiked({required String postId}) async {
    final data = await supabase
        .from('post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', _user.id);

    return data.isNotEmpty;
  }
}
