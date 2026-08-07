class ClanHistoryModel {
  final String id;
  final String clanId;
  final String? userId;
  final String username;
  final String? avatarUrl;
  final String actionType; // 'joined', 'left', 'kicked', 'role_changed', 'post_created', 'event_created', 'tournament_created', 'level_up'
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const ClanHistoryModel({
    required this.id,
    required this.clanId,
    this.userId,
    required this.username,
    this.avatarUrl,
    required this.actionType,
    required this.metadata,
    required this.createdAt,
  });

  factory ClanHistoryModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>? ?? {};
    
    return ClanHistoryModel(
      id: map['id'].toString(),
      clanId: map['clan_id'].toString(),
      userId: map['user_id']?.toString(),
      username: profile['username']?.toString() ?? 'Sistema',
      avatarUrl: profile['avatar_url']?.toString(),
      actionType: map['action_type']?.toString() ?? '',
      metadata: map['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['metadata'])
          : {},
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String get description {
    switch (actionType) {
      case 'clan_created':
        return 'creó el clan "${metadata['clan_name'] ?? ''}" [${metadata['tag'] ?? ''}]';
      case 'joined':
        return 'se unió al clan';
      case 'left':
        return 'salió del clan';
      case 'kicked':
        return 'fue expulsado del clan por ${metadata['by'] ?? 'un admin'}';
      case 'role_changed':
        return 'cambió de rol a "${metadata['role_name'] ?? ''}"';
      case 'post_created':
        return 'creó una nueva publicación en el feed';
      case 'event_created':
        return 'programó un evento: "${metadata['event_name'] ?? ''}"';
      case 'tournament_created':
        return 'creó un torneo: "${metadata['tournament_name'] ?? ''}"';
      case 'level_up':
        return '¡El clan subió al nivel ${metadata['level'] ?? ''}! 🚀';
      default:
        return 'realizó una acción: $actionType';
    }
  }
}
