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

  /// Obtiene una publicación concreta para abrirla desde un mensaje.
  Future<PostModel?> getPostById(String postId) async {
    try {
      final row = await supabase
          .from('posts')
          .select(_postSelectWithShared)
          .eq('id', postId)
          .maybeSingle();
      if (row == null) return null;
      return _mapPosts([
        row,
      ]).then((posts) => posts.isEmpty ? null : posts.first);
    } on PostgrestException {
      final row = await supabase
          .from('posts')
          .select(_postSelect)
          .eq('id', postId)
          .maybeSingle();
      if (row == null) return null;
      return PostModel.fromMap(Map<String, dynamic>.from(row));
    }
  }

  /// Hydrates shared posts when PostgREST cannot expose the nested relation.
  Future<List<PostModel>> _mapPosts(List<dynamic> response) async {
    final rows = response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    // Incluso cuando PostgREST ya entrega `shared_post`, esa relación solo
    // incluye un nivel. Siempre cargamos desde el id para resolver una cadena
    // completa de compartidos hasta la publicación raíz.
    final sourceIds = rows
        .where((row) => row['shared_post_id'] != null)
        .map((row) => row['shared_post_id'].toString())
        .toSet()
        .toList();

    if (sourceIds.isNotEmpty) {
      try {
        final sourcesById = <String, Map<String, dynamic>>{};
        var idsToLoad = sourceIds.toSet();

        // Load the chain in batches. A shared post may itself refer to an
        // older shared post, but the UI should always show the root original.
        for (var depth = 0; depth < 8 && idsToLoad.isNotEmpty; depth++) {
          final sourceRows = await supabase
              .from('posts')
              .select(_postSelect)
              .inFilter('id', idsToLoad.toList());

          idsToLoad = <String>{};
          for (final source in sourceRows) {
            final sourceMap = Map<String, dynamic>.from(source as Map);
            final sourceId = sourceMap['id'].toString();
            if (sourcesById.containsKey(sourceId)) continue;
            sourcesById[sourceId] = sourceMap;

            final parentId = sourceMap['shared_post_id']?.toString();
            if (parentId != null && !sourcesById.containsKey(parentId)) {
              idsToLoad.add(parentId);
            }
          }
        }

        for (final row in rows) {
          final sourceId = row['shared_post_id']?.toString();
          if (sourceId == null) continue;

          var root = sourcesById[sourceId];
          final visitedIds = <String>{row['id'].toString()};
          while (root != null) {
            final rootId = root['id'].toString();
            final parentId = root['shared_post_id']?.toString();
            if (parentId == null || !visitedIds.add(rootId)) break;
            final parent = sourcesById[parentId];
            if (parent == null) break;
            root = parent;
          }

          if (root != null) {
            row['shared_post'] = root;
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

  // ==========================
  // ELIMINAR PUBLICACIÓN
  // ==========================

  /// El filtro por [user_id] es una capa adicional de seguridad en el cliente.
  /// La policy de Supabase sigue siendo la autoridad que impide borrar posts
  /// de otra persona.
  Future<void> deletePost(String postId) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    await supabase
        .from('posts')
        .delete()
        .eq('id', postId)
        .eq('user_id', user.id);
  }
}
