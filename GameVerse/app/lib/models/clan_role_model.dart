class ClanRoleModel {
  final String id;
  final String clanId;
  final String name;
  final int level;

  // Permissions
  final bool canManageMembers;
  final bool canKick;
  final bool canCreateTournaments;
  final bool canManageTournaments;
  final bool canCreateEvents;
  final bool canManageEvents;
  final bool canManageVoice;
  final bool canPostAnnouncements;
  final bool canEditClan;

  const ClanRoleModel({
    required this.id,
    required this.clanId,
    required this.name,
    required this.level,
    required this.canManageMembers,
    required this.canKick,
    required this.canCreateTournaments,
    required this.canManageTournaments,
    required this.canCreateEvents,
    required this.canManageEvents,
    required this.canManageVoice,
    required this.canPostAnnouncements,
    required this.canEditClan,
  });

  factory ClanRoleModel.fromMap(Map<String, dynamic> map) {
    // Si viene la relación clan_permissions
    final perms = map['clan_permissions'] as Map<String, dynamic>? ?? {};
    
    return ClanRoleModel(
      id: map['id'].toString(),
      clanId: map['clan_id'].toString(),
      name: map['name']?.toString() ?? '',
      level: int.tryParse(map['level']?.toString() ?? '10') ?? 10,
      canManageMembers: perms['can_manage_members'] == true,
      canKick: perms['can_kick'] == true,
      canCreateTournaments: perms['can_create_tournaments'] == true,
      canManageTournaments: perms['can_manage_tournaments'] == true,
      canCreateEvents: perms['can_create_events'] == true,
      canManageEvents: perms['can_manage_events'] == true,
      canManageVoice: perms['can_manage_voice'] == true,
      canPostAnnouncements: perms['can_post_announcements'] == true,
      canEditClan: perms['can_edit_clan'] == true,
    );
  }
}
