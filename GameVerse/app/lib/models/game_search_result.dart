class GameSearchResult {
  const GameSearchResult({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.platforms,
  });

  final int id;
  final String name;
  final String? coverUrl;
  final List<String> platforms;

  String get suggestedPlatform => platforms.isEmpty ? 'PC' : platforms.first;

  factory GameSearchResult.fromMap(Map<String, dynamic> map) =>
      GameSearchResult(
        id: (map['id'] as num?)?.toInt() ?? 0,
        name: map['name']?.toString() ?? 'Juego',
        coverUrl: map['cover_url']?.toString(),
        platforms: (map['platforms'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList(),
      );
}
