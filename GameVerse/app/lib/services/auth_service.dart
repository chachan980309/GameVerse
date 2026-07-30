import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
      },
    );

    final user = response.user;

    if (user != null) {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'username': username,
        'email': email,
      });
    }

    return response;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  bool get isLoggedIn => currentUser != null;
}
