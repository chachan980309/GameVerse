import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/voice_channel.dart';

class VoiceChannelService {
  VoiceChannelService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<VoiceChannel>> fetchChannels({
    String query = '',
    int offset = 0,
    int limit = 40,
  }) async {
    var request = _client
        .from('voice_channels')
        .select()
        .eq('is_active', true)
        .eq('is_private', false);
    final cleanQuery = query.trim().replaceAll('%', r'\%');
    if (cleanQuery.isNotEmpty) {
      request = request.or(
        'name.ilike.%$cleanQuery%,description.ilike.%$cleanQuery%',
      );
    }
    final rows = await request
        .order('is_featured', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map(VoiceChannel.fromMap).toList();
  }

  Future<List<VoiceChannel>> fetchJoinedChannels() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('voice_channel_members')
        .select('voice_channels(*)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false)
        .limit(40);
    return rows
        .map((row) => row['voice_channels'])
        .whereType<Map<String, dynamic>>()
        .where((channelMap) => channelMap['is_private'] != true)
        .map(VoiceChannel.fromMap)
        .toList();
  }

  Future<VoiceChannel> createChannel({
    required String name,
    required String description,
    String? avatarUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Debes iniciar sesión.');
    final roomName =
        'nubzzz_${userId.replaceAll('-', '')}_${DateTime.now().microsecondsSinceEpoch}';
    final encodedDescription = avatarUrl != null && avatarUrl.isNotEmpty
        ? '$avatarUrl||$description'
        : description;

    final row = await _client
        .from('voice_channels')
        .insert({
          'name': name.trim(),
          'room_name': roomName,
          'description': encodedDescription.trim(),
          'created_by': userId,
        })
        .select()
        .single();
    final channel = VoiceChannel.fromMap(row);
    await joinChannel(channel.id);
    return channel;
  }

  Future<void> joinChannel(String channelId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Debes iniciar sesión.');
    await _client.from('voice_channel_members').upsert({
      'channel_id': channelId,
      'user_id': userId,
      'joined_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'channel_id,user_id');
  }

  Future<void> leaveChannel(String channelId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('voice_channel_members')
        .delete()
        .eq('channel_id', channelId)
        .eq('user_id', userId);
  }
}
