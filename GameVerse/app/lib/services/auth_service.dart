import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // INICIAR SESIÓN
  // ============================================================

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ============================================================
  // REGISTRO
  // ============================================================

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final cleanEmail = email.trim();
    final cleanUsername = username.trim();

    final response = await _supabase.auth.signUp(
      email: cleanEmail,
      password: password,
      data: {'username': cleanUsername},
    );

    final user = response.user;

    if (user != null) {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'username': cleanUsername,
        'email': cleanEmail,
      });
    }

    return response;
  }

  // ============================================================
  // CERRAR SESIÓN
  // ============================================================

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ============================================================
  // USUARIO ACTUAL
  // ============================================================

  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  // ============================================================
  // SESIÓN ACTUAL
  // ============================================================

  Session? get currentSession {
    return _supabase.auth.currentSession;
  }

  // ============================================================
  // ESTADO DE SESIÓN
  // ============================================================

  bool get isLoggedIn {
    return currentUser != null;
  }

  // ============================================================
  // RECUPERAR CONTRASEÑA
  // ============================================================

  Future<void> resetPassword(String email) async {
    final cleanEmail = email.trim();

    if (cleanEmail.isEmpty) {
      throw Exception('Ingresa tu correo electrónico');
    }

    String redirectUrl;

    if (kIsWeb) {
      // En desarrollo:
      // http://localhost:xxxxx
      //
      // En producción:
      // https://nubzzz.site
      //
      // NO agregamos #/reset-password.
      redirectUrl = Uri.base.origin;
    } else {
      redirectUrl = 'https://nubzzz.site';
    }

    debugPrint('======================================');

    debugPrint('ENVIANDO RECUPERACIÓN DE CONTRASEÑA');

    debugPrint('Correo: $cleanEmail');

    debugPrint('Redirect URL: $redirectUrl');

    await _supabase.auth.resetPasswordForEmail(
      cleanEmail,
      redirectTo: redirectUrl,
    );

    debugPrint('Correo de recuperación enviado correctamente.');

    debugPrint('======================================');
  }

  // ============================================================
  // ACTUALIZAR CONTRASEÑA
  // ============================================================

  Future<UserResponse> updatePassword(String newPassword) async {
    final password = newPassword.trim();

    if (password.isEmpty) {
      throw Exception('La contraseña no puede estar vacía');
    }

    if (password.length < 6) {
      throw Exception('La contraseña debe tener al menos 6 caracteres');
    }

    debugPrint('Actualizando contraseña...');

    final response = await _supabase.auth.updateUser(
      UserAttributes(password: password),
    );

    debugPrint('Contraseña actualizada correctamente.');

    return response;
  }
}
