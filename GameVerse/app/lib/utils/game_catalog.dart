class GameCatalog {
  static String badgeFor(String gameName) {
    final words = gameName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'GV';
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length.clamp(1, 3))
          .toUpperCase();
    }
    return words.take(3).map((word) => word[0]).join().toUpperCase();
  }
}
