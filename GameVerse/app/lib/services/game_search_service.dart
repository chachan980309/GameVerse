import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game_search_result.dart';

class GameSearchService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const _functionUrl =
      'https://kspeynuvzzglafckkiza.supabase.co/functions/v1/clever-api';
  // Es la clave pública del proyecto: no es una clave de servicio ni un secreto.
  static const _publishableKey =
      'sb_publishable_3adr9c84mh5xpbvFs6nEDA_AtKjC-7m';

  Future<List<GameSearchResult>> search(String query) async {
    final term = query.trim();
    if (term.length < 2) return [];

    final preferredQuery = _preferredQuery(term);
    var games = await _searchIgdb(preferredQuery);
    if (games.isEmpty && preferredQuery != term) {
      games = await _searchIgdb(term);
    }
    // Mientras el usuario escribe una frase, la última palabra suele estar
    // incompleta. IGDB no hace búsqueda difusa, así que reintentamos sin ella.
    if (games.isEmpty) {
      final words = term.split(RegExp(r'\s+'));
      if (words.length > 1) {
        games = await _searchIgdb(words.take(words.length - 1).join(' '));
      }
    }
    return _rank(games, preferredQuery);
  }

  /// Corrige nombres muy comunes de la comunidad sin limitar el resto del
  /// catálogo, que siempre sigue viniendo de IGDB.
  String _preferredQuery(String query) {
    final value = _normalize(query);
    if (value == 'lol' || value.startsWith('league')) {
      return 'League of Legends';
    }
    if (value.startsWith('val')) return 'Valorant';
    if (value.startsWith('for') ||
        value.contains('fornite') ||
        value.contains('forniite')) {
      return 'Fortnite';
    }
    if (value.startsWith('mine')) return 'Minecraft';
    if (value.startsWith('apex')) return 'Apex Legends';
    if (value.startsWith('rock')) return 'Rocket League';
    if (value.startsWith('coun') || value == 'cs' || value.startsWith('cs ')) {
      return 'Counter-Strike 2';
    }
    return query;
  }

  List<GameSearchResult> _rank(List<GameSearchResult> games, String query) {
    final needle = _normalize(query);
    final ranked = [...games];
    ranked.sort(
      (first, second) =>
          _score(second, needle).compareTo(_score(first, needle)),
    );
    return ranked;
  }

  int _score(GameSearchResult game, String query) {
    final name = _normalize(game.name);
    if (name == query) return 1000;
    if (name.startsWith(query)) return 800;
    if (name.contains(query)) return 600;
    final words = query.split(' ').where((word) => word.length > 2);
    return words.where(name.contains).length * 100;
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  Future<List<GameSearchResult>> _searchIgdb(String query) async {
    final accessToken = _supabase.auth.currentSession?.accessToken;
    final response = await http.post(
      Uri.parse(_functionUrl),
      headers: {
        'Content-Type': 'application/json',
        'apikey': _publishableKey,
        'Authorization': 'Bearer ${accessToken ?? _publishableKey}',
      },
      body: jsonEncode({'query': query}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'La búsqueda respondió con código ${response.statusCode}.',
      );
    }
    final dynamic data = jsonDecode(response.body);
    if (data is! Map) return [];
    final rawGames = data['games'];
    if (rawGames is! List) return [];
    return rawGames
        .whereType<Map>()
        .map(
          (game) => GameSearchResult.fromMap(Map<String, dynamic>.from(game)),
        )
        .where((game) => game.id > 0 && game.name.isNotEmpty)
        .toList();
  }
}
