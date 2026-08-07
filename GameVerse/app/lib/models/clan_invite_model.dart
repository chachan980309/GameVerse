import 'package:supabase_flutter/supabase_flutter.dart';

class ClanInviteModel {
  final String id;
  final String clanId;
  final String clanName;
  final String? clanLogo;
  final String inviteeId;
  final String inviterId;
  final String inviterUsername;
  final DateTime createdAt;
  final String status; // pending, accepted, rejected, cancelled

  const ClanInviteModel({
    required this.id,
    required this.clanId,
    required this.clanName,
    this.clanLogo,
    required this.inviteeId,
    required this.inviterId,
    required this.inviterUsername,
    required this.createdAt,
    required this.status,
  });

  factory ClanInviteModel.fromMap(Map<String, dynamic> map) {
    final clanMap = map['clans'] as Map<String, dynamic>? ?? {};
    final inviterProfile = map['inviter'] as Map<String, dynamic>? ?? {};

    String? logoUrl = clanMap['logo_url']?.toString();
    if (logoUrl != null && logoUrl.isNotEmpty && !logoUrl.startsWith('http')) {
      logoUrl = Supabase.instance.client.storage.from('clans').getPublicUrl(logoUrl);
    }

    return ClanInviteModel(
      id: map['id'].toString(),
      clanId: map['clan_id'].toString(),
      clanName: clanMap['name']?.toString() ?? 'Clan',
      clanLogo: logoUrl,
      inviteeId: map['invitee_id'].toString(),
      inviterId: map['inviter_id'].toString(),
      inviterUsername: inviterProfile['username']?.toString() ?? 'Miembro',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      status: map['status']?.toString() ?? 'pending',
    );
  }
}
