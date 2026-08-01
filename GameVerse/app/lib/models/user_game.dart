class UserGame {
  const UserGame({
    required this.id,
    required this.gameName,
    required this.platform,
    required this.hoursPlayed,
    required this.isFavorite,
    this.rank,
  });

  final String id;
  final String gameName;
  final String platform;
  final int hoursPlayed;
  final String? rank;
  final bool isFavorite;

  factory UserGame.fromMap(Map<String, dynamic> map) => UserGame(
        id: map['id'].toString(),
        gameName: map['game_name']?.toString() ?? 'Juego',
        platform: map['platform']?.toString() ?? '',
        hoursPlayed: (map['hours_played'] as num?)?.toInt() ?? 0,
        rank: map['rank']?.toString(),
        isFavorite: map['is_favorite'] == true,
      );
}
