import 'package:supabase_flutter/supabase_flutter.dart';

class MentionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final text = query.trim();
    if (text.isEmpty) return [];
    final currentUserId = _supabase.auth.currentUser?.id;
    final result = await _supabase
        .from('profiles')
        .select('id, username, avatar_url')
        .ilike('username', '%$text%')
        .limit(5);
    return List<Map<String, dynamic>>.from(result)
        .where((profile) => profile['id']?.toString() != currentUserId)
        .toList();
  }

  Future<String?> userIdForUsername(String username) async {
    final profile = await _supabase
        .from('profiles')
        .select('id')
        .ilike('username', username)
        .maybeSingle();
    return profile?['id']?.toString();
  }
}
