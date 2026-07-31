import 'package:supabase_flutter/supabase_flutter.dart';

class FriendService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Buscar todos los usuarios excepto el actual
  Future<List<Map<String, dynamic>>> searchUsers() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuario no autenticado.');
    }

    final data = await _supabase
        .from('profiles')
        .select()
        .neq('id', user.id)
        .order('username');

    return List<Map<String, dynamic>>.from(data);
  }

  /// Enviar solicitud de amistad
  Future<void> sendFriendRequest(String receiverId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuario no autenticado.');
    }

    if (user.id == receiverId) {
      throw Exception('No puedes agregarte a ti mismo.');
    }

    final existing = await _supabase
        .from('friendships')
        .select()
        .or(
          'and(sender_id.eq.${user.id},receiver_id.eq.$receiverId),and(sender_id.eq.$receiverId,receiver_id.eq.${user.id})',
        )
        .maybeSingle();

    if (existing != null) {
      throw Exception('Ya existe una solicitud o amistad.');
    }

    await _supabase.from('friendships').insert({
      'sender_id': user.id,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  /// Obtener amigos
  Future<List<Map<String, dynamic>>> getFriends() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuario no autenticado.');
    }

    final data = await _supabase
        .from('friendships')
        .select()
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
        .eq('status', 'accepted');

    return List<Map<String, dynamic>>.from(data);
  }

  /// Solicitudes pendientes
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuario no autenticado.');
    }

    final data = await _supabase
        .from('friendships')
        .select()
        .eq('receiver_id', user.id)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(data);
  }

  /// Aceptar solicitud
  Future<void> acceptRequest(String friendshipId) async {
    await _supabase
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
  }

  /// Rechazar solicitud
  Future<void> rejectRequest(String friendshipId) async {
    await _supabase.from('friendships').delete().eq('id', friendshipId);
  }

  /// Eliminar amigo
  Future<void> removeFriend(String friendshipId) async {
    await _supabase.from('friendships').delete().eq('id', friendshipId);
  }

  /// Bloquear usuario
  Future<void> blockUser(String friendshipId) async {
    await _supabase
        .from('friendships')
        .update({'status': 'blocked'})
        .eq('id', friendshipId);
  }

  /// Verifica si ya existe una amistad o solicitud
  Future<bool> hasFriendRequest(String userId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return false;

    final data = await _supabase
        .from('friendships')
        .select()
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}');

    for (final row in data) {
      if ((row['sender_id'] == user.id && row['receiver_id'] == userId) ||
          (row['sender_id'] == userId && row['receiver_id'] == user.id)) {
        return true;
      }
    }

    return false;
  } //
} //
