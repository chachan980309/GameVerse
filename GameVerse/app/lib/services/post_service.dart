import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post_model.dart';
import '../controllers/profile_controller.dart';

class PostService {
  final SupabaseClient supabase = Supabase.instance.client;

  static bool _hasClansTable = true;

  static const _postSelectWithClans = '''
    *,
    profiles (
      username,
      avatar_url
    ),
    clans (
      name
    )
  ''';

  static const _postSelectWithoutClans = '''
    *,
    profiles (
      username,
      avatar_url
    )
  ''';

  Future<List<dynamic>> _safeSelectQuery(Future<List<dynamic>> Function(String selectStr) queryBuilder) async {
    try {
      if (_hasClansTable) {
        return await queryBuilder(_postSelectWithClans);
      } else {
        return await queryBuilder(_postSelectWithoutClans);
      }
    } catch (e) {
      if (_hasClansTable) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('clans') || errorStr.contains('relation') || errorStr.contains('not found')) {
          debugPrint('⚠️ DB Warning: clans table not found or query failed. Falling back to legacy posts select. Error: $e');
          _hasClansTable = false;
          try {
            return await queryBuilder(_postSelectWithoutClans);
          } catch (retryError) {
            debugPrint('Critical Error: legacy retry failed. Error: $retryError');
            rethrow;
          }
        }
      }
      rethrow;
    }
  }

  String get _postSelect => _hasClansTable ? _postSelectWithClans : _postSelectWithoutClans;

  // ==========================
  // OBTENER FEED
  // ==========================

  Future<List<PostModel>> getFeedPosts({int offset = 0, int limit = 20}) async {
    final response = await _getFeedRows(offset: offset, limit: limit);

    debugPrint("===== FEED (Offset: $offset, Limit: $limit) =====");

    return _mapPosts(response);
  }

  Future<List<PostModel>> getClanPosts(String clanId, {int offset = 0, int limit = 20}) async {
    final response = await supabase
        .from('posts')
        .select(_postSelect)
        .eq('clan_id', clanId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return _mapPosts(response);
  }

  // ==========================
  // POSTS DE UN USUARIO
  // ==========================

  Future<List<PostModel>> getUserPosts(String userId, {int offset = 0, int limit = 20}) async {
    final response = await _getUserRows(userId, offset: offset, limit: limit);

    return _mapPosts(response);
  }

  /// Obtiene una publicación concreta para abrirla desde un mensaje.
  Future<PostModel?> getPostById(String postId) async {
    final row = await supabase
        .from('posts')
        .select(_postSelect)
        .eq('id', postId)
        .maybeSingle();
    if (row == null) return null;
    final posts = await _mapPosts([row]);
    return posts.isEmpty ? null : posts.first;
  }

  /// Hydrates shared posts by ID, avoiding a self-referencing PostgREST join
  /// that may be absent from the server schema cache.
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

  Future<List<dynamic>> _getFeedRows({int offset = 0, int limit = 20}) async {
    return _safeSelectQuery((selectStr) => supabase
        .from('posts')
        .select(selectStr)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1));
  }

  Future<List<dynamic>> _getUserRows(String userId, {int offset = 0, int limit = 20}) async {
    return _safeSelectQuery((selectStr) => supabase
        .from('posts')
        .select(selectStr)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1));
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
        'post-videos/${DateTime.now().millisecondsSinceEpoch}.$extension';

    debugPrint("Subiendo video...");

    await supabase.storage
        .from('post-videos')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '31536000',
            upsert: false,
          ),
        );

    final url = supabase.storage.from('post-videos').getPublicUrl(fileName);

    debugPrint("Video subido:");
    debugPrint(url);

    return url;
  }

  // ==========================
  // SUBIR MINIATURA DE VIDEO
  // ==========================

  Future<String> uploadThumbnail(Uint8List bytes, String originalName) async {
    final extension = originalName.split('.').last;
    final fileName = 'post-thumbnails/${DateTime.now().millisecondsSinceEpoch}.$extension';

    debugPrint("Subiendo miniatura a post-thumbnails bucket...");

    await supabase.storage
        .from('post-thumbnails')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    final url = supabase.storage.from('post-thumbnails').getPublicUrl(fileName);

    debugPrint("Miniatura subida con éxito: $url");
    return url;
  }

  // ==========================
  // CREAR POST
  // ==========================

  Future<void> createPost({
    required String content,
    String? imageUrl,
    String? videoUrl,
    String? thumbnailUrl,
    String? duration,
    int? width,
    int? height,
    double? aspectRatio,
    String type = "text",
    String? sharedPostId,
    String? streamId,
    String? clanId,
    bool clanOnly = false,
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
    debugPrint("Thumbnail: $thumbnailUrl");
    debugPrint("Duration: $duration");
    debugPrint("Width: $width, Height: $height, AspectRatio: $aspectRatio");
    debugPrint("Clan: $clanId, Clan Only: $clanOnly");

    await supabase.from('posts').insert({
      'user_id': user.id,
      'content': content,
      'image': imageUrl,
      'video': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'duration': duration,
      'width': width,
      'height': height,
      'aspect_ratio': aspectRatio,
      'type': type,
      'shared_post_id': sharedPostId,
      'stream_id': streamId,
      'clan_id': clanId,
      'clan_only': clanOnly,
    });

    if (clanId != null) {
      // Award clan XP for posting
      final clanSvc = await supabase.from('clans').select('name').eq('id', clanId).maybeSingle();
      if (clanSvc != null) {
        // En lugar de instanciar o importar ClanService directamente y causar posibles ciclos,
        // incrementamos la experiencia del clan de manera directa en la DB o llamamos a awardClanXP.
        // Como ya tenemos ClanService disponible (o podemos hacer un select/update),
        // usemos una ráfaga simple de SQL para sumarle 25 XP al clan.
        try {
          final clanData = await supabase.from('clans').select('experience, level').eq('id', clanId).single();
          final currentXp = int.tryParse(clanData['experience'].toString()) ?? 0;
          final currentLevel = int.tryParse(clanData['level'].toString()) ?? 1;
          final newXp = currentXp + 25;
          final newLevel = (newXp / 1000).floor() + 1;
          
          final updates = {'experience': newXp};
          if (newLevel > currentLevel) {
            updates['level'] = newLevel;
          }
          await supabase.from('clans').update(updates).eq('id', clanId);

          if (newLevel > currentLevel) {
            await supabase.from('clan_history').insert({
              'clan_id': clanId,
              'user_id': user.id,
              'action_type': 'level_up',
              'metadata': {'level': newLevel},
            });
          } else {
            await supabase.from('clan_history').insert({
              'clan_id': clanId,
              'user_id': user.id,
              'action_type': 'post_created',
              'metadata': {'username': ProfileController.instance.username},
            });
          }
        } catch (_) {}
      }
    }

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
