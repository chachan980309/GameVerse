import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/profile_controller.dart';

class LikeService {
  final SupabaseClient supabase = Supabase.instance.client;

  User get _user {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Debes iniciar sesion para dar Me gusta.');
    }
    return user;
  }

  Future<void> addLike({required String postId}) async {
    await supabase.from('post_likes').upsert({
      'post_id': postId,
      'user_id': _user.id,
    }, onConflict: 'post_id,user_id');
    await ProfileController.instance.loadProfile();
  }

  Future<void> removeLike({required String postId}) async {
    await supabase
        .from('post_likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', _user.id);
  }

  Future<int> getLikes(String postId) async {
    final data = await supabase
        .from('post_likes')
        .select('id')
        .eq('post_id', postId);
    return data.length;
  }

  Future<bool> hasLiked({required String postId}) async {
    final data = await supabase
        .from('post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', _user.id);
    return data.isNotEmpty;
  }
}
