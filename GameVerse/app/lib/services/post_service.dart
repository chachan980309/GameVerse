import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post_model.dart';

class PostService {
  final SupabaseClient supabase = Supabase.instance.client;

  // ==========================
  // OBTENER FEED
  // ==========================

  Future<List<PostModel>> getFeedPosts() async {
    final response = await supabase
        .from('posts')
        .select('''
          *,
          profiles (
            username,
            avatar_url
          )
        ''')
        .order('created_at', ascending: false);

    debugPrint("===== FEED =====");
    debugPrint(response.toString());

    return response.map<PostModel>((e) => PostModel.fromMap(e)).toList();
  }

  // ==========================
  // POSTS DE UN USUARIO
  // ==========================

  Future<List<PostModel>> getUserPosts(String userId) async {
    final response = await supabase
        .from('posts')
        .select('''
          *,
          profiles (
            username,
            avatar_url
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response.map<PostModel>((e) => PostModel.fromMap(e)).toList();
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
    });

    debugPrint("========== INSERT OK ==========");
  }
}
