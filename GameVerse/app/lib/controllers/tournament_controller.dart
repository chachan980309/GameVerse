import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tournament_model.dart';
import '../services/tournament_service.dart';

class TournamentController extends ChangeNotifier {
  static final TournamentController instance = TournamentController._internal();
  factory TournamentController() => instance;
  TournamentController._internal() {
    _subscribeRealtime();
  }

  final TournamentService _service = TournamentService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<TournamentModel> tournaments = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  String activeCategory = 'all';
  String activeQuery = '';
  Map<String, int> communityStats = const {};

  RealtimeChannel? _subscription;

  Future<void> loadTournaments({bool reset = true}) async {
    if (isLoading || (isLoadingMore && !reset)) return;

    if (reset) {
      isLoading = true;
      hasMore = true;
      tournaments = [];
    } else {
      isLoadingMore = true;
    }
    notifyListeners();

    try {
      final offset = reset ? 0 : tournaments.length;
      final results = await _service.fetchTournaments(
        query: activeQuery,
        category: activeCategory,
        offset: offset,
        limit: 10,
      );

      if (results.length < 10) {
        hasMore = false;
      }

      if (reset) {
        tournaments = results;
      } else {
        tournaments.addAll(results);
      }
    } catch (e) {
      debugPrint("Error loading tournaments: $e");
    } finally {
      isLoading = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadCommunityStats() async {
    try {
      communityStats = await _service.getCommunityStats();
    } catch (e) {
      debugPrint('Error loading tournament community stats: $e');
    }
    notifyListeners();
  }

  void setFilter({String? category, String? query}) {
    if (category != null) activeCategory = category;
    if (query != null) activeQuery = query;
    loadTournaments(reset: true);
  }

  Future<void> joinTournament(String tournamentId) async {
    await _service.joinTournament(tournamentId);
    // Realtime trigger will handle the list update, but we also fetch immediately for snappy UX
    await _refreshTournamentById(tournamentId);
  }

  Future<void> leaveTournament(String tournamentId) async {
    await _service.leaveTournament(tournamentId);
    // Realtime trigger will handle the list update, but we also fetch immediately for snappy UX
    await _refreshTournamentById(tournamentId);
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
    final newTournament = await _service.createTournament(
      name: name,
      description: description,
      gameName: gameName,
      gameImageUrl: gameImageUrl,
      gamePosterUrl: gamePosterUrl,
      gameHeroUrl: gameHeroUrl,
      gameBackgroundUrl: gameBackgroundUrl,
      coverBytes: coverBytes,
      coverName: coverName,
      bannerBytes: bannerBytes,
      bannerName: bannerName,
      rules: rules,
      prizes: prizes,
      maxPlayers: maxPlayers,
      startDate: startDate,
      type: type,
      privacy: privacy,
      password: password,
      region: region,
      isOfficial: isOfficial,
    );

    // Insert into the local list and notify
    tournaments.insert(0, newTournament);
    notifyListeners();
    return newTournament;
  }

  Future<void> deleteTournament(String id) async {
    await _service.deleteTournament(id);
    tournaments.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> updateTournamentStatus(String id, String newStatus) async {
    await _service.updateTournamentStatus(id, newStatus);
    await _refreshTournamentById(id);
  }

  Future<void> initializeBracket(String tournamentId) async {
    await _service.initializeBracket(tournamentId);
    await _refreshTournamentById(tournamentId);
  }

  Future<OrganizerStatsModel?> getOrganizerStats(String organizerId) async {
    return _service.getOrganizerStats(organizerId);
  }

  Future<void> reportTournament(
    String tournamentId,
    String reason,
    String details,
  ) async {
    await _service.reportTournament(tournamentId, reason, details);
  }

  Future<void> _refreshTournamentById(String id) async {
    final updated = await _service.getTournamentById(id);
    if (updated != null) {
      final index = tournaments.indexWhere((t) => t.id == id);
      if (index != -1) {
        tournaments[index] = updated;
      } else {
        tournaments.add(updated);
      }
      notifyListeners();
    }
  }

  void _subscribeRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _subscription?.unsubscribe();
    _subscription = _supabase
        .channel('public:tournaments-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tournaments',
          callback: (payload) {
            final row = payload.newRecord;
            final oldRow = payload.oldRecord;
            final eventType = payload.eventType;

            if (eventType == PostgresChangeEvent.delete) {
              final deletedId = oldRow?['id']?.toString();
              if (deletedId != null) {
                tournaments.removeWhere((t) => t.id == deletedId);
                notifyListeners();
              }
            } else {
              final id = row['id']?.toString();
              if (id != null) {
                _refreshTournamentById(id);
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tournament_participants',
          callback: (payload) {
            final row = payload.newRecord;
            final oldRow = payload.oldRecord;

            final id = (row['tournament_id'] ?? oldRow?['tournament_id'])
                ?.toString();
            if (id != null) {
              _refreshTournamentById(id);
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}
