import 'clan_role_model.dart';

class ClanMemberModel {
  final String clanId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String? roleId;
  final ClanRoleModel? role;
  final DateTime joinedAt;

  const ClanMemberModel({
    required this.clanId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.roleId,
    this.role,
    required this.joinedAt,
  });

  factory ClanMemberModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>? ?? {};
    final roleMap = map['clan_roles'] as Map<String, dynamic>?;

    return ClanMemberModel(
      clanId: map['clan_id'].toString(),
      userId: map['user_id'].toString(),
      username: profile['username']?.toString() ?? 'Usuario',
      avatarUrl: profile['avatar_url']?.toString(),
      roleId: map['role_id']?.toString(),
      role: roleMap != null ? ClanRoleModel.fromMap(roleMap) : null,
      joinedAt: DateTime.tryParse(map['joined_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
