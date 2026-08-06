import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tournament_model.dart';

class TournamentService {
  TournamentService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<TournamentModel>> fetchTournaments({
    String query = '',
    String category = 'all',
    int offset = 0,
    int limit = 10,
  }) async {
    var request = _client.from('tournaments').select('''
      *,
      creator:profiles!tournaments_creator_id_fkey(*),
      tournament_participants(*, profiles!tournament_participants_user_id_fkey(*))
    ''');

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

    // Paginate and sort
    final rows = await request
        .order('is_official', ascending: false)
        .order('start_date', ascending: true)
        .range(offset, offset + limit - 1);

    return rows.map((row) => TournamentModel.fromMap(row)).toList();
  }

  Future<TournamentModel?> getTournamentById(String id) async {
    try {
      final row = await _client
          .from('tournaments')
          .select('''
            *,
            creator:profiles!tournaments_creator_id_fkey(*),
            tournament_participants(*, profiles!tournament_participants_user_id_fkey(*))
          ''')
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return TournamentModel.fromMap(row);
    } catch (e) {
      debugPrint("Error fetching tournament by ID: $e");
      return null;
    }
  }

  Future<String?> uploadFile(Uint8List bytes, String bucketName, String fileName) async {
    try {
      final ext = fileName.split('.').last;
      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${(bytes.length % 1000)}.$ext';
      
      await _client.storage.from(bucketName).uploadBinary(
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

    final row = await _client.from('tournaments').insert({
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
    }).select('''
      *,
      creator:profiles!tournaments_creator_id_fkey(*),
      tournament_participants(*, profiles!tournament_participants_user_id_fkey(*))
    ''').single();

    return TournamentModel.fromMap(row);
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

  Future<void> updateTournamentStatus(String tournamentId, String newStatus) async {
    await _client.from('tournaments').update({'status': newStatus}).eq('id', tournamentId);
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

  Future<void> reportTournament(String tournamentId, String reason, String details) async {
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
