import 'package:supabase_flutter/supabase_flutter.dart';

class ClanModel {
  final String id;
  final String name;
  final String tag;
  final String description;
  final String? logoUrl;
  final String? bannerUrl;
  final String region;
  final String language;
  final String visibility; // public, private, invite_only
  final String clanType; // casual, competitive
  final int maxMembers;
  final String ownerId;
  final DateTime createdAt;
  final bool verified;
  final int level;
  final int experience;
  final String accentColor;
  final String? mainGameId;

  // Stats desnormalizadas
  final int tournamentsCreated;
  final int tournamentsWon;
  final int eventsHosted;
  final int membersCount;
  final int postsCount;

  const ClanModel({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    this.logoUrl,
    this.bannerUrl,
    required this.region,
    required this.language,
    required this.visibility,
    required this.clanType,
    required this.maxMembers,
    required this.ownerId,
    required this.createdAt,
    required this.verified,
    required this.level,
    required this.experience,
    required this.accentColor,
    this.mainGameId,
    required this.tournamentsCreated,
    required this.tournamentsWon,
    required this.eventsHosted,
    required this.membersCount,
    required this.postsCount,
  });

  factory ClanModel.fromMap(Map<String, dynamic> map) {
    String? logoUrl = map['logo_url']?.toString();
    if (logoUrl != null && logoUrl.isNotEmpty && !logoUrl.startsWith('http')) {
      logoUrl = Supabase.instance.client.storage.from('clans').getPublicUrl(logoUrl);
    }

    String? bannerUrl = map['banner_url']?.toString();
    if (bannerUrl != null && bannerUrl.isNotEmpty && !bannerUrl.startsWith('http')) {
      bannerUrl = Supabase.instance.client.storage.from('clans').getPublicUrl(bannerUrl);
    }

    return ClanModel(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? '',
      tag: map['tag']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      logoUrl: logoUrl,
      bannerUrl: bannerUrl,
      region: map['region']?.toString() ?? 'Global',
      language: map['language']?.toString() ?? 'Español',
      visibility: map['visibility']?.toString() ?? 'public',
      clanType: map['clan_type']?.toString() ?? 'casual',
      maxMembers: int.tryParse(map['max_members']?.toString() ?? '50') ?? 50,
      ownerId: map['owner_id']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      verified: map['verified'] == true,
      level: int.tryParse(map['level']?.toString() ?? '1') ?? 1,
      experience: int.tryParse(map['experience']?.toString() ?? '0') ?? 0,
      accentColor: map['accent_color']?.toString() ?? '#6438FF',
      mainGameId: map['main_game_id']?.toString(),
      tournamentsCreated: int.tryParse(map['tournaments_created']?.toString() ?? '0') ?? 0,
      tournamentsWon: int.tryParse(map['tournaments_won']?.toString() ?? '0') ?? 0,
      eventsHosted: int.tryParse(map['events_hosted']?.toString() ?? '0') ?? 0,
      membersCount: int.tryParse(map['members_count']?.toString() ?? '1') ?? 1,
      postsCount: int.tryParse(map['posts_count']?.toString() ?? '0') ?? 0,
    );
  }
}
