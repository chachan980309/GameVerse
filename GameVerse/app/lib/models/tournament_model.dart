import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentModel {
  final String id;
  final String name;
  final String description;
  final String gameName;
  final String? gameImageUrl;
  final String? coverUrl;
  final String? bannerUrl;
  final String? gamePosterUrl;
  final String? gameHeroUrl;
  final String? gameBackgroundUrl;
  final String? rules;
  final String? prizes;
  final int maxPlayers;
  final DateTime startDate;
  final String type; // 'single_elimination' | 'double_elimination' | 'round_robin'
  final String status; // 'draft' | 'registration' | 'full' | 'in_progress' | 'finished' | 'cancelled' | 'archived'
  final String privacy; // 'public' | 'private'
  final String? password;
  final String region;
  final String creatorId;
  final String creatorName;
  final String creatorAvatar;
  final bool isOfficial;
  final bool markedForReview;
  final DateTime createdAt;
  final String? clanId;
  final String? clanName;
  final String? clanLogo;
  
  // Extra fields populated via queries
  final int participantCount;
  final List<TournamentParticipantModel> participants;

  const TournamentModel({
    required this.id,
    required this.name,
    required this.description,
    required this.gameName,
    this.gameImageUrl,
    this.coverUrl,
    this.bannerUrl,
    this.gamePosterUrl,
    this.gameHeroUrl,
    this.gameBackgroundUrl,
    this.rules,
    this.prizes,
    required this.maxPlayers,
    required this.startDate,
    required this.type,
    required this.status,
    required this.privacy,
    this.password,
    required this.region,
    required this.creatorId,
    required this.creatorName,
    required this.creatorAvatar,
    required this.isOfficial,
    this.markedForReview = false,
    required this.createdAt,
    this.clanId,
    this.clanName,
    this.clanLogo,
    this.participantCount = 0,
    this.participants = const [],
  });

  factory TournamentModel.fromMap(Map<String, dynamic> map, {List<TournamentParticipantModel> participants = const []}) {
    String? sanitizeUrl(String? url) {
      if (url == null || url.isEmpty) return null;
      if (url.startsWith('//')) {
        return 'https:$url';
      }
      return url;
    }

    // Resolve dynamic image urls from Supabase storage if short paths are saved
    String? coverUrl = map['cover_url']?.toString();
    if (coverUrl != null && coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
      coverUrl = Supabase.instance.client.storage.from('tournaments').getPublicUrl(coverUrl);
    }
    coverUrl = sanitizeUrl(coverUrl);
    
    String? bannerUrl = map['banner_url']?.toString();
    if (bannerUrl != null && bannerUrl.isNotEmpty && !bannerUrl.startsWith('http')) {
      bannerUrl = Supabase.instance.client.storage.from('tournaments').getPublicUrl(bannerUrl);
    }
    bannerUrl = sanitizeUrl(bannerUrl);

    final rawParticipantsList = map['tournament_participants'] as List<dynamic>? ?? [];
    final parsedParticipants = rawParticipantsList.map((p) {
      final pMap = p as Map<String, dynamic>;
      return TournamentParticipantModel.fromMap(pMap);
    }).toList();

    final creatorProfile = map['creator'] as Map<String, dynamic>? ?? {};
    final creatorName = creatorProfile['username']?.toString() ?? 'Usuario';
    final creatorAvatar = creatorProfile['avatar_url']?.toString() ?? '';

    final clanMap = map['clans'] as Map<String, dynamic>?;
    final clanName = clanMap?['name']?.toString();
    var clanLogo = clanMap?['logo_url']?.toString();
    if (clanLogo != null && clanLogo.isNotEmpty && !clanLogo.startsWith('http')) {
      clanLogo = Supabase.instance.client.storage.from('clans').getPublicUrl(clanLogo);
    }
    clanLogo = sanitizeUrl(clanLogo);

    // Soporte para retrocompatibilidad total (Fallbacks dinámicos)
    final gameImageUrl = sanitizeUrl(map['game_image_url']?.toString());
    final legacyImageFallback = coverUrl ?? bannerUrl ?? gameImageUrl;
    final gamePosterUrl = sanitizeUrl(map['game_poster_url']?.toString()) ?? legacyImageFallback;
    final gameHeroUrl = sanitizeUrl(map['game_hero_url']?.toString()) ?? legacyImageFallback;
    final gameBackgroundUrl = sanitizeUrl(map['game_background_url']?.toString()) ?? legacyImageFallback;

    return TournamentModel(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      gameName: map['game_name']?.toString() ?? '',
      gameImageUrl: gameImageUrl,
      coverUrl: coverUrl,
      bannerUrl: bannerUrl,
      gamePosterUrl: gamePosterUrl,
      gameHeroUrl: gameHeroUrl,
      gameBackgroundUrl: gameBackgroundUrl,
      rules: map['rules']?.toString(),
      prizes: map['prizes']?.toString(),
      maxPlayers: int.tryParse(map['max_players']?.toString() ?? '16') ?? 16,
      startDate: DateTime.tryParse(map['start_date']?.toString() ?? '') ?? DateTime.now(),
      type: map['type']?.toString() ?? 'single_elimination',
      status: map['status']?.toString() ?? 'registration',
      privacy: map['privacy']?.toString() ?? 'public',
      password: map['password']?.toString(),
      region: map['region']?.toString() ?? 'LATAM',
      creatorId: map['creator_id']?.toString() ?? '',
      creatorName: creatorName,
      creatorAvatar: creatorAvatar,
      isOfficial: map['is_official'] == true,
      markedForReview: map['marked_for_review'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      clanId: map['clan_id']?.toString(),
      clanName: clanName,
      clanLogo: clanLogo,
      participantCount: map['participant_count'] != null 
          ? int.tryParse(map['participant_count'].toString()) ?? parsedParticipants.length
          : parsedParticipants.length,
      participants: participants.isNotEmpty ? participants : parsedParticipants,
    );
  }

  TournamentModel copyWith({
    String? id,
    String? name,
    String? description,
    String? gameName,
    String? gameImageUrl,
    String? coverUrl,
    String? bannerUrl,
    String? gamePosterUrl,
    String? gameHeroUrl,
    String? gameBackgroundUrl,
    String? rules,
    String? prizes,
    int? maxPlayers,
    DateTime? startDate,
    String? type,
    String? status,
    String? privacy,
    String? password,
    String? region,
    String? creatorId,
    String? creatorName,
    String? creatorAvatar,
    bool? isOfficial,
    bool? markedForReview,
    DateTime? createdAt,
    String? clanId,
    String? clanName,
    String? clanLogo,
    int? participantCount,
    List<TournamentParticipantModel>? participants,
  }) {
    return TournamentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      gameName: gameName ?? this.gameName,
      gameImageUrl: gameImageUrl ?? this.gameImageUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      gamePosterUrl: gamePosterUrl ?? this.gamePosterUrl,
      gameHeroUrl: gameHeroUrl ?? this.gameHeroUrl,
      gameBackgroundUrl: gameBackgroundUrl ?? this.gameBackgroundUrl,
      rules: rules ?? this.rules,
      prizes: prizes ?? this.prizes,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      startDate: startDate ?? this.startDate,
      type: type ?? this.type,
      status: status ?? this.status,
      privacy: privacy ?? this.privacy,
      password: password ?? this.password,
      region: region ?? this.region,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorAvatar: creatorAvatar ?? this.creatorAvatar,
      isOfficial: isOfficial ?? this.isOfficial,
      markedForReview: markedForReview ?? this.markedForReview,
      createdAt: createdAt ?? this.createdAt,
      clanId: clanId ?? this.clanId,
      clanName: clanName ?? this.clanName,
      clanLogo: clanLogo ?? this.clanLogo,
      participantCount: participantCount ?? this.participantCount,
      participants: participants ?? this.participants,
    );
  }
}

class TournamentParticipantModel {
  final String tournamentId;
  final String userId;
  final String username;
  final String avatarUrl;
  final DateTime joinedAt;

  const TournamentParticipantModel({
    required this.tournamentId,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.joinedAt,
  });

  factory TournamentParticipantModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>? ?? {};
    return TournamentParticipantModel(
      tournamentId: map['tournament_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      username: profile['username']?.toString() ?? 'Usuario',
      avatarUrl: profile['avatar_url']?.toString() ?? '',
      joinedAt: DateTime.tryParse(map['joined_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class OrganizerStatsModel {
  final String organizerId;
  final int createdCount;
  final int finishedCount;
  final int cancelledCount;
  final int totalParticipants;
  final double rating;

  const OrganizerStatsModel({
    required this.organizerId,
    required this.createdCount,
    required this.finishedCount,
    required this.cancelledCount,
    required this.totalParticipants,
    required this.rating,
  });

  factory OrganizerStatsModel.fromMap(Map<String, dynamic> map) {
    return OrganizerStatsModel(
      organizerId: map['organizer_id']?.toString() ?? '',
      createdCount: int.tryParse(map['created_count']?.toString() ?? '0') ?? 0,
      finishedCount: int.tryParse(map['finished_count']?.toString() ?? '0') ?? 0,
      cancelledCount: int.tryParse(map['cancelled_count']?.toString() ?? '0') ?? 0,
      totalParticipants: int.tryParse(map['total_participants']?.toString() ?? '0') ?? 0,
      rating: double.tryParse(map['rating']?.toString() ?? '5.0') ?? 5.0,
    );
  }
}
