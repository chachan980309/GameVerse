import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/direct_message.dart';

class DirectMessageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  Future<List<DirectMessage>> getConversation(String otherUserId) async {
    final userId = currentUserId;
    if (userId.isEmpty) return [];
    final data = await _supabase
        .from('direct_messages')
        .select()
        .or('and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)')
        .order('created_at');
    return data.map<DirectMessage>((item) => DirectMessage.fromMap(item)).toList();
  }

  Future<void> sendMessage(String receiverId, String content) async {
    final userId = currentUserId;
    final text = content.trim();
    if (userId.isEmpty) throw Exception('Usuario no autenticado.');
    if (text.isEmpty) return;
    await _supabase.from('direct_messages').insert({
      'sender_id': userId,
      'receiver_id': receiverId,
      'content': text,
    });
  }
}
