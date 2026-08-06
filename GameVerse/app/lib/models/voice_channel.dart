import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceChannelMember {
  const VoiceChannelMember({
    required this.userId,
    required this.username,
    required this.avatarUrl,
  });

  final String userId;
  final String username;
  final String avatarUrl;
}

class VoiceChannel {
  const VoiceChannel({
    required this.id,
    required this.name,
    required this.roomName,
    required this.description,
    required this.createdBy,
    required this.isFeatured,
    this.memberCount = 0,
    this.avatarUrl = '',
    this.members = const [],
    this.isPrivate = false,
    this.inviteeId,
    this.privateStatus,
  });

  factory VoiceChannel.fromMap(Map<String, dynamic> map) {
    final rawDesc = map['description']?.toString() ?? '';
    String avatarUrl = '';
    String description = rawDesc;
    if (rawDesc.contains('||')) {
      final parts = rawDesc.split('||');
      final pathOrUrl = parts[0];
      description = parts.sublist(1).join('||');

      if (pathOrUrl.isNotEmpty) {
        if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
          avatarUrl = pathOrUrl;
        } else {
          // Reconstruir la URL pública dinámicamente desde la ruta relativa corta
          avatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(pathOrUrl);
        }
      }
    }

    // Compatibilidad retrospectiva para URLs de imagen guardadas directamente en columnas alternativas
    if (avatarUrl.isEmpty) {
      final dbUrl = (map['image_url'] ?? map['avatar_url'] ?? map['avatarUrl'] ?? '')?.toString() ?? '';
      if (dbUrl.isNotEmpty) {
        avatarUrl = dbUrl;
      }
    }

    final membersList = map['voice_channel_members'] as List<dynamic>? ?? [];
    final members = membersList.map((m) {
      final memberMap = m as Map<String, dynamic>;
      final profile = memberMap['profiles'] as Map<String, dynamic>? ?? {};
      return VoiceChannelMember(
        userId: memberMap['user_id']?.toString() ?? '',
        username: profile['username']?.toString() ?? 'Usuario',
        avatarUrl: profile['avatar_url']?.toString() ?? '',
      );
    }).toList();

    // Compatibilidad retrospectiva para el ID del creador
    final creatorId = (map['created_by'] ?? map['creator_id'] ?? map['owner_id'] ?? map['createdBy'] ?? '')?.toString() ?? '';

    return VoiceChannel(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Canal de voz',
      roomName: map['room_name']?.toString() ?? '',
      description: description,
      createdBy: creatorId,
      isFeatured: map['is_featured'] == true,
      memberCount: members.length,
      avatarUrl: avatarUrl,
      members: members,
      isPrivate: map['is_private'] == true,
      inviteeId: map['invitee_id']?.toString(),
      privateStatus: map['private_status']?.toString(),
    );
  }

  final String id;
  final String name;
  final String roomName;
  final String description;
  final String createdBy;
  final bool isFeatured;
  final int memberCount;
  final String avatarUrl;
  final List<VoiceChannelMember> members;
  final bool isPrivate;
  final String? inviteeId;
  final String? privateStatus;
}
