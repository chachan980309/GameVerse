import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tournament_model.dart';
import '../models/tournament_bracket_match.dart';

class TournamentService {
  TournamentService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static bool _hasClansTable = true;

  /// Métricas globales del área de torneos, calculadas en PostgreSQL para que
  /// el encabezado no dependa del filtro ni de la paginación visible.
  Future<Map<String, int>> getCommunityStats() async {
    try {
      final rows = await _client.rpc('get_tournament_community_stats');
      if (rows is! List || rows.isEmpty) return const {};
      final row = Map<String, dynamic>.from(rows.first as Map);
      int value(String key) => int.tryParse(row[key]?.toString() ?? '') ?? 0;
      return {
        'tournaments': value('tournaments_count'),
        'participants': value('participants_count'),
        'live': value('live_count'),
        'upcoming': value('upcoming_count'),
      };
    } catch (e) {
      debugPrint('Error getting tournament community stats: $e');
      return const {};
    }
  }

  Future<List<dynamic>> _safeSelectQuery(
    Future<List<dynamic>> Function(String selectStr) queryBuilder,
  ) async {
    const selectWithClans = '''
      *,
      creator:profiles!tournaments_creator_id_fkey(*),
      clans(*),
      tournament_participants(*, profiles!tournament_participants_user_id_fkey(*))
    ''';

    const selectWithoutClans = '''
      *,
      creator:profiles!tournaments_creator_id_fkey(*),
      tournament_participants(*, profiles!tournament_participants_user_id_fkey(*))
    ''';

    try {
      if (_hasClansTable) {
        return await queryBuilder(selectWithClans);
      } else {
        return await queryBuilder(selectWithoutClans);
      }
    } catch (e) {
      if (_hasClansTable) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('clans') ||
            errorStr.contains('relation') ||
            errorStr.contains('not found')) {
          debugPrint(
            '⚠️ DB Warning: clans table not found or query failed. Falling back to legacy tournaments select. Error: $e',
          );
          _hasClansTable = false;
          try {
            return await queryBuilder(selectWithoutClans);
          } catch (retryError) {
            debugPrint(
              'Critical Error: legacy tournaments retry failed. Error: $retryError',
            );
            rethrow;
          }
        }
      }
      rethrow;
    }
  }

  Future<List<TournamentModel>> fetchTournaments({
    String query = '',
    String category = 'all',
    int offset = 0,
    int limit = 10,
  }) async {
    try {
      final rows = await _safeSelectQuery((selectStr) async {
        var request = _client.from('tournaments').select(selectStr);

        // Apply category filters
        switch (category) {
          case 'official':
            request = request.eq('is_official', true);
            break;
          case 'community':
            request = request.eq('is_official', false);
            break;
          case 'live':
            request = request.eq('status', 'in_progress');
            break;
          case 'upcoming':
            request = request.eq('status', 'registration');
            break;
          case 'finished':
            request = request.eq('status', 'finished');
            break;
        }

        if (category != 'finished') {
          request = request.neq('status', 'archived');
        }

        // Apply search query (by game or name)
        final cleanQuery = query.trim().replaceAll('%', r'\%');
        if (cleanQuery.isNotEmpty) {
          request = request.or(
            'name.ilike.%$cleanQuery%,game_name.ilike.%$cleanQuery%',
          );
        }

        return await request
            .order('is_official', ascending: false)
            .order('start_date', ascending: true)
            .range(offset, offset + limit - 1);
      });

      return rows.map((row) => TournamentModel.fromMap(row)).toList();
    } catch (e) {
      debugPrint("Error fetching tournaments: $e");
      return [];
    }
  }

  Future<TournamentModel?> getTournamentById(String id) async {
    try {
      final rows = await _safeSelectQuery((selectStr) async {
        final row = await _client
            .from('tournaments')
            .select(selectStr)
            .eq('id', id)
            .maybeSingle();
        return row == null ? [] : [row];
      });

      if (rows.isEmpty) return null;
      return TournamentModel.fromMap(rows.first);
    } catch (e) {
      debugPrint("Error fetching tournament by ID: $e");
      return null;
    }
  }

  Future<String?> uploadFile(
    Uint8List bytes,
    String bucketName,
    String fileName,
  ) async {
    try {
      final ext = fileName.split('.').last;
      final uniqueName =
          '${DateTime.now().millisecondsSinceEpoch}_${(bytes.length % 1000)}.$ext';

      await _client.storage
          .from(bucketName)
          .uploadBinary(
            uniqueName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return uniqueName;
    } catch (e) {
      debugPrint("Error uploading file to storage bucket: $e");
      return null;
    }
  }

  Future<TournamentModel> createTournament({
    required String name,
    required String description,
    required String gameName,
    String? gameImageUrl,
    String? gamePosterUrl,
    String? gameHeroUrl,
    String? gameBackgroundUrl,
    Uint8List? coverBytes,
    String? coverName,
    Uint8List? bannerBytes,
    String? bannerName,
    String? rules,
    String? prizes,
    required int maxPlayers,
    required DateTime startDate,
    required String type,
    required String privacy,
    String? password,
    required String region,
    required bool isOfficial,
    String? clanId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception("Usuario no autenticado");

    String? coverUrl;
    if (coverBytes != null && coverName != null) {
      coverUrl = await uploadFile(coverBytes, 'tournaments', coverName);
    } else if (gameImageUrl != null && gameImageUrl.isNotEmpty) {
      // Auto-extract high-res 1080p game banner from IGDB cover URL
      var cleanUrl = gameImageUrl;
      if (cleanUrl.startsWith('//')) {
        cleanUrl = 'https:$cleanUrl';
      }
      coverUrl = cleanUrl
          .replaceAll('/t_thumb/', '/t_1080p/')
          .replaceAll('/t_cover_small/', '/t_1080p/')
          .replaceAll('/t_cover_big/', '/t_1080p/')
          .replaceAll('/t_logo_med/', '/t_1080p/');
    }

    String? bannerUrl;
    if (bannerBytes != null && bannerName != null) {
      bannerUrl = await uploadFile(bannerBytes, 'tournaments', bannerName);
    } else {
      bannerUrl = coverUrl;
    }

    final row = await _safeSelectQuery((selectStr) async {
      final insertRow = await _client
          .from('tournaments')
          .insert({
            'name': name,
            'description': description,
            'game_name': gameName,
            'game_image_url': gameImageUrl,
            'game_poster_url': gamePosterUrl ?? coverUrl,
            'game_hero_url': gameHeroUrl ?? coverUrl,
            'game_background_url': gameBackgroundUrl ?? coverUrl,
            'cover_url': coverUrl,
            'banner_url': bannerUrl,
            'rules': rules,
            'prizes': prizes,
            'max_players': maxPlayers,
            'start_date': startDate.toIso8601String(),
            'type': type,
            'privacy': privacy,
            'password': password,
            'region': region,
            'creator_id': userId,
            'is_official': isOfficial,
            'clan_id': clanId,
          })
          .select(selectStr)
          .single();
      return [insertRow];
    });

    return TournamentModel.fromMap(row.first);
  }

  Future<void> transferOwnershipToClan(
    String tournamentId,
    String clanId,
  ) async {
    await _client
        .from('tournaments')
        .update({'clan_id': clanId})
        .eq('id', tournamentId);
  }

  Future<void> joinTournament(String tournamentId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception("Usuario no autenticado");

    await _client.from('tournament_participants').insert({
      'tournament_id': tournamentId,
      'user_id': userId,
    });
  }

  Future<void> leaveTournament(String tournamentId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception("Usuario no autenticado");

    await _client
        .from('tournament_participants')
        .delete()
        .eq('tournament_id', tournamentId)
        .eq('user_id', userId);
  }

  Future<void> deleteTournament(String tournamentId) async {
    await _client.from('tournaments').delete().eq('id', tournamentId);
  }

  Future<void> updateTournamentStatus(
    String tournamentId,
    String newStatus,
  ) async {
    await _client
        .from('tournaments')
        .update({'status': newStatus})
        .eq('id', tournamentId);
  }

  Future<void> initializeBracket(String tournamentId) async {
    await _client.rpc(
      'initialize_tournament_bracket',
      params: {'target_tournament_id': tournamentId},
    );
  }

  Future<void> reportMatchWinner(String matchId, String winnerId) async {
    await _client.rpc(
      'report_tournament_match_winner',
      params: {'target_match_id': matchId, 'target_winner_id': winnerId},
    );
  }

  Future<List<TournamentBracketMatch>> getBracketMatches(
    String tournamentId,
  ) async {
    final rows = await _client
        .from('tournament_matches')
        .select(
          '*, player_one:profiles!tournament_matches_player_one_id_fkey(id, username), player_two:profiles!tournament_matches_player_two_id_fkey(id, username), winner:profiles!tournament_matches_winner_id_fkey(id, username)',
        )
        .eq('tournament_id', tournamentId)
        .order('round_number')
        .order('match_number');
    return rows
        .map(
          (row) =>
              TournamentBracketMatch.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<OrganizerStatsModel?> getOrganizerStats(String organizerId) async {
    try {
      final row = await _client
          .from('organizer_stats')
          .select()
          .eq('organizer_id', organizerId)
          .maybeSingle();

      if (row == null) return null;
      return OrganizerStatsModel.fromMap(row);
    } catch (e) {
      debugPrint("Error fetching organizer stats: $e");
      return null;
    }
  }

  Future<void> reportTournament(
    String tournamentId,
    String reason,
    String details,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception("Usuario no autenticado");

    await _client.from('tournament_reports').insert({
      'tournament_id': tournamentId,
      'reporter_id': userId,
      'reason': reason,
      'details': details,
    });
  }
}
