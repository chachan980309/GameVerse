class UserGame {
  const UserGame({
    required this.id,
    required this.gameName,
    required this.platform,
    required this.hoursPlayed,
    required this.isFavorite,
    required this.gamerTag,
    required this.logoUrl,
    this.coverUrl = '',
    this.igdbId,
    this.rank,
  });

  final String id;
  final String gameName;
  final String platform;
  final int hoursPlayed;
  final String? rank;
  final bool isFavorite;
  final String gamerTag;
  final String logoUrl;
  final String coverUrl;
  final int? igdbId;

  String get imageUrl => coverUrl.isNotEmpty ? coverUrl : logoUrl;

  factory UserGame.fromMap(Map<String, dynamic> map) => UserGame(
    id: map['id'].toString(),
    gameName: map['game_name']?.toString() ?? 'Juego',
    platform: map['platform']?.toString() ?? '',
    hoursPlayed: (map['hours_played'] as num?)?.toInt() ?? 0,
    rank: map['rank']?.toString(),
    isFavorite: map['is_favorite'] == true,
    gamerTag: map['gamer_tag']?.toString() ?? '',
    logoUrl: map['logo_url']?.toString() ?? '',
    coverUrl: map['cover_url']?.toString() ?? map['logo_url']?.toString() ?? '',
    igdbId: (map['igdb_id'] as num?)?.toInt(),
  );
}
