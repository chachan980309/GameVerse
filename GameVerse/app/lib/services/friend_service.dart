import 'package:supabase_flutter/supabase_flutter.dart';

class FriendService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> searchUsers() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return [];

    final response = await _supabase
        .from('profiles')
        .select()
        .neq('id', user.id)
        .order('username');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> sendFriendRequest(String receiverId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    await _supabase.from('friendships').insert({
      'sender_id': user.id,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return [];

    final response = await _supabase
        .from('friendships')
        .select()
        .eq('receiver_id', user.id)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> acceptRequest(String friendshipId) async {
    await _supabase
        .from('friendships')
        .update({
          'status': 'accepted',
        })
        .eq('id', friendshipId);
  }

  Future<void> rejectRequest(String friendshipId) async {
    await _supabase
        .from('friendships')
        .delete()
        .eq('id', friendshipId);
  }

  Future<List<Map<String, dynamic>>> getFriends() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return [];

    final response = await _supabase
        .from('friendships')
        .select()
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
        .eq('status', 'accepted');

    return List<Map<String, dynamic>>.from(response);
  }
}