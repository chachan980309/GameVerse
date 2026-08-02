import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_game.dart';
import '../models/game_search_result.dart';

class UserGamesService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<UserGame>> getMyGames() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    return getGamesForUser(user.id);
  }

  Future<List<UserGame>> getGamesForUser(String userId) async {
    final data = await _supabase
        .from('user_games')
        .select()
        .eq('user_id', userId)
        .order('is_favorite', ascending: false)
        .order('created_at', ascending: false);
    return data.map<UserGame>((item) => UserGame.fromMap(item)).toList();
  }

  Future<void> addGame({
    required GameSearchResult game,
    required String platform,
    required int hoursPlayed,
    String? rank,
    required bool isFavorite,
    required String gamerTag,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado.');
    await _supabase.from('user_games').insert({
      'user_id': user.id,
      'game_name': game.name,
      'platform': platform,
      'hours_played': hoursPlayed,
      'rank': rank?.isEmpty == true ? null : rank,
      'is_favorite': isFavorite,
      'gamer_tag': gamerTag.trim(),
      'igdb_id': game.id,
      'cover_url': game.coverUrl,
      'logo_url': game.coverUrl ?? '',
      'game_source': 'igdb',
    });
  }

  Future<void> removeGame(String id) =>
      _supabase.from('user_games').delete().eq('id', id);
}
