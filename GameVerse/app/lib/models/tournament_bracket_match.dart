class TournamentBracketMatch {
  const TournamentBracketMatch({
    required this.id,
    required this.roundNumber,
    required this.matchNumber,
    required this.playerOneId,
    required this.playerOneName,
    required this.playerTwoId,
    required this.playerTwoName,
    required this.winnerId,
    required this.status,
  });

  final String id;
  final int roundNumber;
  final int matchNumber;
  final String? playerOneId;
  final String? playerOneName;
  final String? playerTwoId;
  final String? playerTwoName;
  final String? winnerId;
  final String status;

  bool get isCompleted => status == 'completed';

  factory TournamentBracketMatch.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? profile(String key) =>
        map[key] is Map ? Map<String, dynamic>.from(map[key] as Map) : null;
    final p1 = profile('player_one');
    final p2 = profile('player_two');
    return TournamentBracketMatch(
      id: map['id'].toString(),
      roundNumber: int.tryParse(map['round_number'].toString()) ?? 1,
      matchNumber: int.tryParse(map['match_number'].toString()) ?? 1,
      playerOneId: map['player_one_id']?.toString(),
      playerOneName: p1?['username']?.toString(),
      playerTwoId: map['player_two_id']?.toString(),
      playerTwoName: p2?['username']?.toString(),
      winnerId: map['winner_id']?.toString(),
      status: map['status']?.toString() ?? 'pending',
    );
  }
}
