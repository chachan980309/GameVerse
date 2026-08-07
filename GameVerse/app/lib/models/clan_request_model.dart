class ClanRequestModel {
  final String id;
  final String clanId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String message;
  final DateTime createdAt;
  final String status; // pending, accepted, rejected

  const ClanRequestModel({
    required this.id,
    required this.clanId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.message,
    required this.createdAt,
    required this.status,
  });

  factory ClanRequestModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>? ?? {};

    return ClanRequestModel(
      id: map['id'].toString(),
      clanId: map['clan_id'].toString(),
      userId: map['user_id'].toString(),
      username: profile['username']?.toString() ?? 'Usuario',
      avatarUrl: profile['avatar_url']?.toString(),
      message: map['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      status: map['status']?.toString() ?? 'pending',
    );
  }
}
