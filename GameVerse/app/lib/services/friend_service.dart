import 'package:supabase_flutter/supabase_flutter.dart';

class FriendService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  Future<List<Map<String, dynamic>>> searchUsers() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado.');

    final data = await _supabase
        .from('profiles')
        .select()
        .neq('id', user.id)
        .order('username');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Creates the request and returns its identifier so it can be cancelled.
  Future<String> sendFriendRequest(String receiverId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado.');
    if (user.id == receiverId)
      throw Exception('No puedes agregarte a ti mismo.');

    final existing = await _supabase
        .from('friendships')
        .select('id')
        .or(
          'and(sender_id.eq.${user.id},receiver_id.eq.$receiverId),and(sender_id.eq.$receiverId,receiver_id.eq.${user.id})',
        )
        .maybeSingle();
    if (existing != null) throw Exception('Ya existe una solicitud o amistad.');

    final created = await _supabase
        .from('friendships')
        .insert({
          'sender_id': user.id,
          'receiver_id': receiverId,
          'status': 'pending',
        })
        .select('id')
        .single();
    return created['id'] as String;
  }

  Future<List<Map<String, dynamic>>> getFriends() => getAcceptedFriends();

  Future<int> countAcceptedFriends(String userId) async {
    final data = await _supabase
        .from('friendships')
        .select('id')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .eq('status', 'accepted');
    return data.length;
  }

  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final user = _requireUser();
    final data = await _supabase
        .from('friendships')
        .select(
          'id, sender_id, receiver_id, sender:profiles!friendships_sender_id_fkey(*)',
        )
        .eq('receiver_id', user.id)
        .eq('status', 'pending');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getOutgoingRequests() async {
    final user = _requireUser();
    final data = await _supabase
        .from('friendships')
        .select(
          'id, sender_id, receiver_id, receiver:profiles!friendships_receiver_id_fkey(*)',
        )
        .eq('sender_id', user.id)
        .eq('status', 'pending');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getAcceptedFriends() async {
    final user = _requireUser();
    final data = await _supabase
        .from('friendships')
        .select(
          'id, sender_id, receiver_id, sender:profiles!friendships_sender_id_fkey(*), receiver:profiles!friendships_receiver_id_fkey(*)',
        )
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
        .eq('status', 'accepted');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final user = _requireUser();
    final data = await _supabase
        .from('friendships')
        .select(
          'id, sender_id, receiver_id, sender:profiles!friendships_sender_id_fkey(*), receiver:profiles!friendships_receiver_id_fkey(*)',
        )
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
        .eq('status', 'blocked');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> acceptRequest(String friendshipId) => _supabase
      .from('friendships')
      .update({'status': 'accepted'})
      .eq('id', friendshipId);

  Future<void> rejectRequest(String friendshipId) =>
      _supabase.from('friendships').delete().eq('id', friendshipId);

  Future<void> cancelFriendRequest(String friendshipId) =>
      _supabase.from('friendships').delete().eq('id', friendshipId);

  Future<void> removeFriend(String friendshipId) =>
      _supabase.from('friendships').delete().eq('id', friendshipId);

  Future<void> blockUser(String friendshipId) => _supabase
      .from('friendships')
      .update({'status': 'blocked'})
      .eq('id', friendshipId);

  Future<bool> hasFriendRequest(String userId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final data = await _supabase
        .from('friendships')
        .select('id')
        .or(
          'and(sender_id.eq.${user.id},receiver_id.eq.$userId),and(sender_id.eq.$userId,receiver_id.eq.${user.id})',
        );
    return data.isNotEmpty;
  }

  /// Returns the existing friendship/request with [userId], if any.
  Future<Map<String, dynamic>?> getRelationship(String userId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final data = await _supabase
        .from('friendships')
        .select('id, sender_id, receiver_id, status')
        .or(
          'and(sender_id.eq.${user.id},receiver_id.eq.$userId),and(sender_id.eq.$userId,receiver_id.eq.${user.id})',
        )
        .maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  User _requireUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado.');
    return user;
  }
}
