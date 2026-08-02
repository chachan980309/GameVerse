import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post_model.dart';
import '../controllers/profile_controller.dart';

class PostService {
  final SupabaseClient supabase = Supabase.instance.client;

  static const _postSelect = '''
    *,
    profiles (
      username,
      avatar_url
    )
  ''';

  static const _postSelectWithShared = '''
    *,
    profiles (
      username,
      avatar_url
    ),
    shared_post:posts!posts_shared_post_id_fkey (
      *,
      profiles (
        username,
        avatar_url
      )
    )
  ''';

  // ==========================
  // OBTENER FEED
  // ==========================

  Future<List<PostModel>> getFeedPosts() async {
    final response = await _getFeedRows();

    debugPrint("===== FEED =====");
    debugPrint(response.toString());

    return _mapPosts(response);
  }

  // ==========================
  // POSTS DE UN USUARIO
  // ==========================

  Future<List<PostModel>> getUserPosts(String userId) async {
    final response = await _getUserRows(userId);

    return _mapPosts(response);
  }

  /// Hydrates shared posts when PostgREST cannot expose the nested relation.
  Future<List<PostModel>> _mapPosts(List<dynamic> response) async {
    final rows = response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    final sourceIds = rows
        .where(
          (row) => row['shared_post'] == null && row['shared_post_id'] != null,
        )
        .map((row) => row['shared_post_id'].toString())
        .toSet()
        .toList();

    if (sourceIds.isNotEmpty) {
      try {
        final sourceRows = await supabase
            .from('posts')
            .select(_postSelect)
            .inFilter('id', sourceIds);
        final sourcesById = <String, Map<String, dynamic>>{
          for (final source in sourceRows)
            source['id'].toString(): Map<String, dynamic>.from(source as Map),
        };

        for (final row in rows) {
          final sourceId = row['shared_post_id']?.toString();
          if (sourceId != null && sourcesById.containsKey(sourceId)) {
            row['shared_post'] = sourcesById[sourceId];
          }
        }
      } catch (error) {
        debugPrint('Unable to hydrate shared posts: $error');
      }
    }

    return rows.map(PostModel.fromMap).toList();
  }

  Future<List<dynamic>> _getFeedRows() async {
    try {
      return await supabase
          .from('posts')
          .select(_postSelectWithShared)
          .order('created_at', ascending: false);
    } on PostgrestException catch (error) {
      debugPrint('Shared-post relation unavailable, using base feed: $error');
      return await supabase
          .from('posts')
          .select(_postSelect)
          .order('created_at', ascending: false);
    }
  }

  Future<List<dynamic>> _getUserRows(String userId) async {
    try {
      return await supabase
          .from('posts')
          .select(_postSelectWithShared)
          .eq('user_id', userId)
          .order('created_at', ascending: false);
    } on PostgrestException catch (error) {
      debugPrint('Shared-post relation unavailable, using base wall: $error');
      return await supabase
          .from('posts')
          .select(_postSelect)
          .eq('user_id', userId)
          .order('created_at', ascending: false);
    }
  }

  // ==========================
  // SUBIR IMAGEN
  // ==========================

  Future<String> uploadImage(Uint8List bytes, String originalName) async {
    final extension = originalName.split('.').last;

    final fileName =
        'posts/${DateTime.now().millisecondsSinceEpoch}.$extension';

    debugPrint("Subiendo imagen...");

    await supabase.storage
        .from('post-images')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    final url = supabase.storage.from('post-images').getPublicUrl(fileName);

    debugPrint("Imagen subida:");
    debugPrint(url);

    return url;
  }

  // ==========================
  // SUBIR VIDEO
  // ==========================

  Future<String> uploadVideo(Uint8List bytes, String originalName) async {
    final extension = originalName.split('.').last;

    final fileName =
        'videos/${DateTime.now().millisecondsSinceEpoch}.$extension';

    debugPrint("Subiendo video...");

    await supabase.storage
        .from('post-videos')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    final url = supabase.storage.from('post-videos').getPublicUrl(fileName);

    debugPrint("Video subido:");
    debugPrint(url);

    return url;
  }

  // ==========================
  // CREAR POST
  // ==========================

  Future<void> createPost({
    required String content,
    String? imageUrl,
    String? videoUrl,
    String type = "text",
    String? sharedPostId,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception("Usuario no autenticado");
    }

    debugPrint("========== INSERT ==========");
    debugPrint("Usuario: ${user.id}");
    debugPrint("Contenido: $content");
    debugPrint("Imagen: $imageUrl");
    debugPrint("Video: $videoUrl");

    await supabase.from('posts').insert({
      'user_id': user.id,
      'content': content,
      'image': imageUrl,
      'video': videoUrl,
      'type': type,
      'shared_post_id': sharedPostId,
    });
    await ProfileController.instance.loadProfile();

    debugPrint("========== INSERT OK ==========");
  }
}
