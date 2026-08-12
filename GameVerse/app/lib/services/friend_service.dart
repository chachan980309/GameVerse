import 'package:supabase_flutter/supabase_flutter.dart';

class FriendService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  Future<List<Map<String, dynamic>>> searchUsers() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado.');

    final data = await _supabase
        .from('profiles')
        .select(
          'id, username, avatar_url, status, motto, is_online, last_seen_at',
        )
        .neq('id', user.id)
        .order('username');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Creates the request and returns its identifier so it can be cancelled.
  Future<String> sendFriendRequest(String receiverId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado.');
    if (user.id == receiverId) {
      throw Exception('No puedes agregarte a ti mismo.');
    }

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

  Future<List<Map<String, dynamic>>> getSuggestedFriends({
    int limit = 3,
  }) async {
    final user = _requireUser();
    final mine = await getAcceptedFriends();
    final myIds = mine
        .map(
          (row) => row['sender_id'] == user.id
              ? row['receiver_id']?.toString() ?? ''
              : row['sender_id']?.toString() ?? '',
        )
        .where((id) => id.isNotEmpty)
        .toSet();
    if (myIds.isEmpty) return _fallbackSuggestedFriends(limit: limit);
    final rows = await _supabase
        .from('friendships')
        .select(
          'sender_id, receiver_id, sender:profiles!friendships_sender_id_fkey(id, username, avatar_url), receiver:profiles!friendships_receiver_id_fkey(id, username, avatar_url)',
        )
        .eq('status', 'accepted')
        .or(
          'sender_id.in.(${myIds.join(',')}),receiver_id.in.(${myIds.join(',')})',
        );
    final candidates = <String, Map<String, dynamic>>{};
    for (final raw in List<Map<String, dynamic>>.from(rows)) {
      final senderId = raw['sender_id']?.toString() ?? '';
      final receiverId = raw['receiver_id']?.toString() ?? '';
      final id = myIds.contains(senderId) ? receiverId : senderId;
      if (id.isEmpty || id == user.id || myIds.contains(id)) continue;
      final profile = id == senderId ? raw['sender'] : raw['receiver'];
      if (profile is! Map) continue;
      final entry = candidates.putIfAbsent(
        id,
        () => {...Map<String, dynamic>.from(profile), 'mutual_friends': 0},
      );
      entry['mutual_friends'] = (entry['mutual_friends'] as int) + 1;
    }
    final result = candidates.values.toList()
      ..sort(
        (a, b) =>
            (b['mutual_friends'] as int).compareTo(a['mutual_friends'] as int),
      );
    if (result.length >= limit) return result.take(limit).toList();

    final fallback = await _fallbackSuggestedFriends(
      limit: limit - result.length,
      excludedIds: {
        ...myIds,
        ...result.map((candidate) => candidate['id']?.toString() ?? ''),
      },
    );
    return [...result, ...fallback];
  }

  Future<List<Map<String, dynamic>>> _fallbackSuggestedFriends({
    required int limit,
    Set<String> excludedIds = const {},
  }) async {
    final user = _requireUser();
    final relationships = await _supabase
        .from('friendships')
        .select('sender_id, receiver_id')
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}');

    final excluded = <String>{user.id, ...excludedIds};
    for (final row in List<Map<String, dynamic>>.from(relationships)) {
      excluded
        ..add(row['sender_id']?.toString() ?? '')
        ..add(row['receiver_id']?.toString() ?? '');
    }

    final users = await searchUsers();
    return users
        .where((profile) => !excluded.contains(profile['id']?.toString()))
        .take(limit)
        .map((profile) => {...profile, 'mutual_friends': null})
        .toList();
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
