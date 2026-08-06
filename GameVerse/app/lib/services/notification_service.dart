import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getNotifications({int offset = 0, int limit = 10}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    final data = await _supabase
        .from('notifications')
        .select(
          'id, type, post_id, comment_id, created_at, read_at, actor:profiles!notifications_actor_id_fkey(id, username, avatar_url)',
        )
        .eq('recipient_id', user.id)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> markAllRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient_id', user.id)
        .isFilter('read_at', null);
  }
}
