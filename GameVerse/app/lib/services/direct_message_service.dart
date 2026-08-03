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
        .or(
          'and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)',
        )
        .order('created_at', ascending: true);
    return data
        .map<DirectMessage>((item) => DirectMessage.fromMap(item))
        .toList();
  }

  Future<void> sendMessage(
    String receiverId,
    String content, {
    String? sharedPostId,
  }) async {
    final userId = currentUserId;
    final text = content.trim();
    if (userId.isEmpty) throw Exception('Usuario no autenticado.');
    if (text.isEmpty) return;
    await _supabase.from('direct_messages').insert({
      'sender_id': userId,
      'receiver_id': receiverId,
      'content': text,
      'shared_post_id': sharedPostId,
    });
  }

  Future<List<Map<String, dynamic>>> getInbox() async {
    final userId = currentUserId;
    if (userId.isEmpty) return [];
    final data = await _supabase
        .from('direct_messages')
        .select(
          'id, sender_id, content, created_at, read_at, sender:profiles!direct_messages_sender_id_fkey(id, username, avatar_url)',
        )
        .eq('receiver_id', userId)
        .order('created_at', ascending: false);
    final uniqueSenders = <String>{};
    return List<Map<String, dynamic>>.from(data)
        .where((message) => uniqueSenders.add(message['sender_id'].toString()))
        .toList();
  }

  Future<void> markMessagesFromRead(String senderId) async {
    final userId = currentUserId;
    if (userId.isEmpty) return;
    await _supabase
        .from('direct_messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('receiver_id', userId)
        .eq('sender_id', senderId)
        .isFilter('read_at', null);
  }
}
