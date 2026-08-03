import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return null;

    return await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  // ==========================
  // Avatar
  // ==========================

  Future<String> uploadAvatar(Uint8List bytes) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception("Usuario no autenticado");
    }

    // Conservamos el avatar anterior hasta que la nueva imagen esté subida y
    // el perfil apunte a ella. Eliminarlo antes podía dejar el perfil con una
    // URL rota si la subida se interrumpía.
    List<String> previousPaths = const [];
    try {
      final files = await _supabase.storage.from("avatars").list(path: user.id);
      previousPaths = files.map((file) => "${user.id}/${file.name}").toList();
    } catch (_) {
      // La carga del avatar no debe fallar solo porque no se puedan limpiar
      // versiones antiguas.
    }

    // Nuevo nombre único
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.png";
    final path = "${user.id}/$fileName";

    try {
      await _supabase.storage
          .from("avatars")
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: "image/png"),
          );

      final publicUrl = _supabase.storage.from("avatars").getPublicUrl(path);

      await _supabase
          .from("profiles")
          .update({"avatar_url": publicUrl})
          .eq("id", user.id);

      // Ya existe una URL válida en el perfil: ahora sí es seguro liberar
      // archivos previos. Si esta limpieza falla, la foto actual sigue sana.
      final stalePaths = previousPaths
          .where((oldPath) => oldPath != path)
          .toList();
      if (stalePaths.isNotEmpty) {
        try {
          await _supabase.storage.from("avatars").remove(stalePaths);
        } catch (_) {}
      }

      return publicUrl;
    } catch (e, stack) {
      print(e);
      print(stack);
      rethrow;
    }
  }

  // ==========================
  // Banner
  // ==========================

  Future<String> uploadBanner(
    Uint8List bytes, {
    required double verticalPosition,
    required double scale,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception("Usuario no autenticado");
    }

    // Eliminar banner anterior
    final files = await _supabase.storage.from("banners").list(path: user.id);

    if (files.isNotEmpty) {
      final paths = files.map((file) => "${user.id}/${file.name}").toList();

      await _supabase.storage.from("banners").remove(paths);
    }

    // Nuevo nombre único
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.png";
    final path = "${user.id}/$fileName";

    print("======================================");
    print("INICIANDO SUBIDA DE BANNER");
    print("USER ID: ${user.id}");
    print("EMAIL: ${user.email}");
    print("PATH: $path");
    print("======================================");

    try {
      print("Subiendo banner...");

      await _supabase.storage
          .from("banners")
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: "image/png"),
          );

      print("Banner subido correctamente.");

      final publicUrl = _supabase.storage.from("banners").getPublicUrl(path);

      print("URL PUBLICA:");
      print(publicUrl);

      print("Actualizando perfil...");

      await _supabase
          .from("profiles")
          .update({"banner_url": publicUrl})
          .eq("id", user.id);

      // Keep working for existing databases until the migration is applied.
      try {
        await _supabase
            .from("profiles")
            .update({
              "banner_position": verticalPosition,
              "banner_scale": scale,
            })
            .eq("id", user.id);
      } catch (_) {
        // The current session still uses the selected position locally.
      }

      print("Banner actualizado correctamente.");
      print("======================================");

      return publicUrl;
    } catch (e, stack) {
      print("======================================");
      print("ERROR AL SUBIR BANNER");
      print(e);
      print(stack);
      print("======================================");
      rethrow;
    }
  }

  // ==========================
  // Actualizar perfil
  // ==========================

  Future<void> updateProfile({
    String? username,
    String? bio,
    String? status,
    String? handle,
    String? motto,
    String? location,
    String? platform,
    String? role,
    String? favoriteGame,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    final data = <String, dynamic>{};

    if (username != null) data["username"] = username;
    if (bio != null) data["bio"] = bio;
    if (status != null) data["status"] = status;
    if (handle != null) data["handle"] = handle;
    if (motto != null) data["motto"] = motto;
    if (location != null) data["location"] = location;
    if (platform != null) data["platform"] = platform;
    if (role != null) data["role"] = role;
    if (favoriteGame != null) data["favorite_game"] = favoriteGame;

    if (data.isNotEmpty) {
      await _supabase.from("profiles").update(data).eq("id", user.id);
    }
  }
}
