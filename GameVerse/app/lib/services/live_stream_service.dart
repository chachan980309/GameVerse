import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/profile_controller.dart';

class LiveStreamService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> startLiveStream({
    required String title,
    required String roomName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Debes iniciar sesión.');

    final stream = await _supabase
        .from('live_streams')
        .insert({
          'user_id': user.id,
          'room_name': roomName,
          'title': title,
          'is_live': true,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(stream as Map);
  }

  Future<void> endLiveStream(String streamId) async {
    await _supabase
        .from('live_streams')
        .update({'is_live': false, 'ended_at': DateTime.now().toIso8601String()})
        .eq('id', streamId);
  }

  Future<Map<String, dynamic>?> getActiveStream(String streamId) async {
    final row = await _supabase
        .from('live_streams')
        .select()
        .eq('id', streamId)
        .eq('is_live', true)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  Future<String> getLiveKitToken(String roomName) async {
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('Sesión expirada.');

    final response = await _supabase.functions.invoke(
      'livekit-token',
      body: {'room': roomName, 'roomType': 'live'},
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final token = data['token']?.toString() ?? '';
    if (token.split('.').length != 3) {
      throw Exception('Token de LiveKit inválido.');
    }
    return token;
  }

  Stream<List<Map<String, dynamic>>> subscribeToMessages(String streamId) {
    return _supabase
        .from('live_stream_messages')
        .stream(primaryKey: ['id'])
        .eq('stream_id', streamId)
        .order('created_at', ascending: true)
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  Future<void> sendMessage({
    required String streamId,
    required String message,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Debes iniciar sesión.');
    final profile = ProfileController.instance;
    await _supabase.from('live_stream_messages').insert({
      'stream_id': streamId,
      'user_id': user.id,
      'username': profile.username,
      'avatar_url': profile.avatarUrl,
      'message': message,
    });
  }
}
