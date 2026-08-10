import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clan_model.dart';
import '../models/clan_member_model.dart';
import '../models/clan_history_model.dart';
import '../models/clan_request_model.dart';
import '../models/clan_invite_model.dart';
import '../models/clan_event_model.dart';
import '../services/clan_service.dart';

class ClanController extends ChangeNotifier {
  static final ClanController instance = ClanController._();
  ClanController._();

  final ClanService _clanService = ClanService.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Estado del Clan del Usuario Actual
  ClanModel? myClan;
  ClanMemberModel? myMemberInfo;
  bool loadingMyClan = false;

  // Listados (ClansPage)
  List<ClanModel> clans = [];
  bool loadingClans = false;
  int clansOffset = 0;
  bool hasMoreClans = true;

  // Detalle del Clan Seleccionado
  ClanModel? selectedClan;
  List<ClanMemberModel> selectedClanMembers = [];
  List<ClanEventModel> selectedClanEvents = [];
  List<ClanHistoryModel> selectedClanHistory = [];
  List<ClanRequestModel> selectedClanRequests = [];
  bool loadingDetail = false;
  bool loadingHistory = false;
  int historyOffset = 0;
  bool hasMoreHistory = true;

  // Solicitud pendiente del usuario para el clan seleccionado
  ClanRequestModel? myPendingRequest;

  // Información de membresía del usuario para el clan seleccionado
  ClanMemberModel? selectedClanMyMemberInfo;

  // Getters de permisos del clan seleccionado
  bool get selectedClanCanEditClan =>
      (selectedClan?.ownerId == _supabase.auth.currentUser?.id) ||
      (selectedClanMyMemberInfo?.role?.canEditClan ?? false);

  bool get selectedClanCanManageMembers =>
      (selectedClan?.ownerId == _supabase.auth.currentUser?.id) ||
      (selectedClanMyMemberInfo?.role?.canManageMembers ?? false);

  bool get selectedClanCanKick =>
      (selectedClan?.ownerId == _supabase.auth.currentUser?.id) ||
      (selectedClanMyMemberInfo?.role?.canKick ?? false);

  bool get selectedClanCanCreateEvents =>
      (selectedClan?.ownerId == _supabase.auth.currentUser?.id) ||
      (selectedClanMyMemberInfo?.role?.canCreateEvents ?? false);

  bool get selectedClanCanManageEvents =>
      (selectedClan?.ownerId == _supabase.auth.currentUser?.id) ||
      (selectedClanMyMemberInfo?.role?.canManageEvents ?? false);

  bool get selectedClanCanCreateTournaments =>
      (selectedClan?.ownerId == _supabase.auth.currentUser?.id) ||
      (selectedClanMyMemberInfo?.role?.canCreateTournaments ?? false);

  bool get selectedClanCanManageTournaments =>
      (selectedClan?.ownerId == _supabase.auth.currentUser?.id) ||
      (selectedClanMyMemberInfo?.role?.canManageTournaments ?? false);

  bool get selectedClanCanManageVoice =>
      (selectedClan?.ownerId == _supabase.auth.currentUser?.id) ||
      (selectedClanMyMemberInfo?.role?.canManageVoice ?? false);

  bool get selectedClanCanPostAnnouncements =>
      (selectedClan?.ownerId == _supabase.auth.currentUser?.id) ||
      (selectedClanMyMemberInfo?.role?.canPostAnnouncements ?? false);

  // Invitaciones del Usuario
  List<ClanInviteModel> myInvites = [];
  bool loadingInvites = false;

  // Realtime Subscriptions
  RealtimeChannel? _clanChannel;
  RealtimeChannel? _historyChannel;
  RealtimeChannel? _requestsChannel;

  // Getters de permisos
  bool get canEditClan => myMemberInfo?.role?.canEditClan ?? false;
  bool get canManageMembers => myMemberInfo?.role?.canManageMembers ?? false;
  bool get canKick => myMemberInfo?.role?.canKick ?? false;
  bool get canCreateEvents => myMemberInfo?.role?.canCreateEvents ?? false;
  bool get canManageEvents => myMemberInfo?.role?.canManageEvents ?? false;
  bool get canCreateTournaments => myMemberInfo?.role?.canCreateTournaments ?? false;
  bool get canManageTournaments => myMemberInfo?.role?.canManageTournaments ?? false;
  bool get canManageVoice => myMemberInfo?.role?.canManageVoice ?? false;
  bool get canPostAnnouncements => myMemberInfo?.role?.canPostAnnouncements ?? false;

  // ==========================
  // INICIALIZACIÓN / CARGA
  // ==========================

  Future<void> initialize() async {
    await loadMyClan();
    await loadMyInvites();
  }

  Future<void> loadMyClan() async {
    loadingMyClan = true;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        myClan = null;
        myMemberInfo = null;
        return;
      }

      myClan = await _clanService.getMyClan();
      if (myClan != null) {
        myMemberInfo = await _clanService.getClanMember(myClan!.id, userId);
        _setupMyClanRealtime();
      } else {
        myMemberInfo = null;
        _cleanupRealtime();
      }
    } catch (e) {
      debugPrint('Error loading my clan: $e');
    } finally {
      loadingMyClan = false;
      notifyListeners();
    }
  }

  Future<void> loadMyInvites() async {
    loadingInvites = true;
    notifyListeners();

    try {
      myInvites = await _clanService.getMyInvites();
    } catch (e) {
      debugPrint('Error loading my invites: $e');
    } finally {
      loadingInvites = false;
      notifyListeners();
    }
  }

  // ==========================
  // CLANS PAGE
  // ==========================

  Future<void> loadClans({
    bool refresh = false,
    String search = '',
    String? filter,
    String? region,
    String? language,
  }) async {
    if (loadingClans) return;

    if (refresh) {
      clansOffset = 0;
      hasMoreClans = true;
      clans = [];
    }

    if (!hasMoreClans) return;

    loadingClans = true;
    notifyListeners();

    try {
      final loaded = await _clanService.getClans(
        offset: clansOffset,
        limit: 20,
        search: search,
        filter: filter,
        region: region,
        language: language,
      );

      if (loaded.length < 20) {
        hasMoreClans = false;
      }

      clans.addAll(loaded);
      clansOffset += loaded.length;
    } catch (e) {
      debugPrint('Error loading clans list: $e');
    } finally {
      loadingClans = false;
      notifyListeners();
    }
  }

  // ==========================
  // CLAN DETAIL PAGE
  // ==========================

  Future<void> loadClanDetail(String clanId, {bool forceSelected = false}) async {
    loadingDetail = true;
    notifyListeners();

    try {
      if (forceSelected || selectedClan?.id != clanId) {
        selectedClan = await _clanService.getClanById(clanId);
      }

      if (selectedClan != null) {
        selectedClanMembers = await _clanService.getClanMembers(clanId);
        selectedClanEvents = await _clanService.getClanEvents(clanId);
        
        // Carga de historial inicial
        historyOffset = 0;
        hasMoreHistory = true;
        selectedClanHistory = await _clanService.getClanHistory(clanId, offset: historyOffset, limit: 20);
        historyOffset += selectedClanHistory.length;
        if (selectedClanHistory.length < 20) hasMoreHistory = false;

        // Si somos admin del clan seleccionado, cargar solicitudes
        final userId = _supabase.auth.currentUser?.id;
        final isMyClanDetail = myClan?.id == clanId;
        
        selectedClanMyMemberInfo = isMyClanDetail
            ? myMemberInfo
            : selectedClanMembers.cast<ClanMemberModel?>().firstWhere(
                (m) => m?.userId == userId,
                orElse: () => null,
              );

        if (userId != null) {
          myPendingRequest = await _clanService.getMyPendingRequest(clanId);
        } else {
          myPendingRequest = null;
        }

        if (selectedClanMyMemberInfo != null &&
            (selectedClanMyMemberInfo!.role?.canManageMembers == true || selectedClan!.ownerId == userId)) {
          selectedClanRequests = await _clanService.getClanRequests(clanId);
        } else {
          selectedClanRequests = [];
        }

        _setupDetailRealtime(clanId);
      }
    } catch (e) {
      debugPrint('Error loading clan detail: $e');
    } finally {
      loadingDetail = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreHistory() async {
    if (loadingHistory || !hasMoreHistory || selectedClan == null) return;

    loadingHistory = true;
    notifyListeners();

    try {
      final loaded = await _clanService.getClanHistory(selectedClan!.id, offset: historyOffset, limit: 20);
      if (loaded.length < 20) hasMoreHistory = false;

      selectedClanHistory.addAll(loaded);
      historyOffset += loaded.length;
    } catch (e) {
      debugPrint('Error loading more history: $e');
    } finally {
      loadingHistory = false;
      notifyListeners();
    }
  }

  // ==========================
  // ACCIONES DEL CLAN
  // ==========================

  Future<void> deleteClan(String clanId) async {
    try {
      await _clanService.deleteClan(clanId);
      
      if (myClan?.id == clanId) {
        myClan = null;
        myMemberInfo = null;
      }
      
      if (selectedClan?.id == clanId) {
        selectedClan = null;
        selectedClanMembers = [];
        selectedClanEvents = [];
        selectedClanHistory = [];
        selectedClanRequests = [];
        selectedClanMyMemberInfo = null;
      }
      
      await loadMyClan();
      notifyListeners();
    } catch (e) {
      debugPrint('Error en ClanController.deleteClan: $e');
      rethrow;
    }
  }

  Future<ClanModel> createClan({
    required String name,
    required String tag,
    required String description,
    required String region,
    required String language,
    required String visibility,
    required String clanType,
    required String accentColor,
    String? mainGameId,
  }) async {
    final clan = await _clanService.createClan(
      name: name,
      tag: tag,
      description: description,
      region: region,
      language: language,
      visibility: visibility,
      clanType: clanType,
      accentColor: accentColor,
      mainGameId: mainGameId,
    );

    await loadMyClan();
    return clan;
  }

  Future<void> joinClan(String clanId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final clan = await _clanService.getClanById(clanId);
      if (clan == null) return;

      if (clan.visibility == 'public') {
        // Unirse directamente
        final roles = await _clanService.getClanRoles(clanId);
        final memberRole = roles.firstWhere((r) => r.name == 'Member');

        await _supabase.from('clan_members').insert({
          'clan_id': clanId,
          'user_id': userId,
          'role_id': memberRole.id,
        });

        final profile = await _supabase.from('profiles').select('username').eq('id', userId).single();
        final username = profile['username']?.toString() ?? 'Miembro';

        await _clanService.logHistory(
          clanId: clanId,
          userId: userId,
          actionType: 'joined',
          metadata: {'username': username},
        );

        // Premiar clan XP por unirse (+100 XP)
        await _clanService.awardClanXP(clanId, 100);

        await loadMyClan();
        await loadClanDetail(clanId, forceSelected: true);
      } else {
        // Enviar solicitud de ingreso
        await _clanService.createClanRequest(clanId, 'Me gustaría unirme a su clan.');
        await loadClanDetail(clanId, forceSelected: true);
      }
    } catch (e) {
      debugPrint('Error joining clan: $e');
    }
  }

  Future<void> leaveMyClan() async {
    if (myClan == null) return;
    try {
      final clanId = myClan!.id;
      await _clanService.leaveClan(clanId);
      await loadMyClan();
      selectedClan = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error leaving clan: $e');
    }
  }

  Future<void> kickClanMember(String userId) async {
    if (selectedClan == null) return;
    try {
      await _clanService.kickMember(selectedClan!.id, userId);
      await loadClanDetail(selectedClan!.id, forceSelected: true);
      if (userId == _supabase.auth.currentUser?.id) {
        await loadMyClan();
      }
    } catch (e) {
      debugPrint('Error kicking member: $e');
    }
  }

  Future<void> promoteClanMember(String userId, String roleId) async {
    if (selectedClan == null) return;
    try {
      await _clanService.promoteMember(selectedClan!.id, userId, roleId);
      await loadClanDetail(selectedClan!.id, forceSelected: true);
      if (userId == _supabase.auth.currentUser?.id) {
        await loadMyClan();
      }
    } catch (e) {
      debugPrint('Error promoting member: $e');
    }
  }

  // ==========================
  // ACCIONES DE SOLICITUDES & INVITACIONES
  // ==========================

  Future<void> handleClanRequest(String requestId, String status) async {
    if (selectedClan == null) return;
    try {
      await _clanService.updateClanRequestStatus(requestId, selectedClan!.id, status);
      await loadClanDetail(selectedClan!.id, forceSelected: true);
    } catch (e) {
      debugPrint('Error handling clan request: $e');
    }
  }

  Future<void> handleClanInvite(String inviteId, String clanId, String status) async {
    try {
      await _clanService.updateClanInviteStatus(inviteId, clanId, status);
      await loadMyInvites();
      await loadMyClan();
    } catch (e) {
      debugPrint('Error handling clan invite: $e');
    }
  }

  Future<void> inviteUser(String inviteeId) async {
    if (selectedClan == null) return;
    try {
      await _clanService.createClanInvite(selectedClan!.id, inviteeId);
    } catch (e) {
      debugPrint('Error inviting user: $e');
    }
  }

  // ==========================
  // CONFIGURACIÓN / EDICIÓN
  // ==========================

  Future<void> updateClanInfo({
    required String name,
    required String tag,
    required String description,
    required String region,
    required String language,
    required String visibility,
    required String clanType,
    required String accentColor,
    String? mainGameId,
  }) async {
    if (selectedClan == null) return;
    final data = {
      'name': name,
      'tag': tag.toUpperCase(),
      'description': description,
      'region': region,
      'language': language,
      'visibility': visibility,
      'clan_type': clanType,
      'accent_color': accentColor,
      'main_game_id': mainGameId,
    };

    await _clanService.updateClan(selectedClan!.id, data);
    await loadClanDetail(selectedClan!.id, forceSelected: true);
    await loadMyClan();
  }

  Future<void> uploadClanLogo(Uint8List bytes) async {
    if (selectedClan == null) return;
    await _clanService.uploadLogo(selectedClan!.id, bytes);
    await loadClanDetail(selectedClan!.id, forceSelected: true);
    await loadMyClan();
  }

  Future<void> uploadClanBanner(Uint8List bytes) async {
    if (selectedClan == null) return;
    await _clanService.uploadBanner(selectedClan!.id, bytes);
    await loadClanDetail(selectedClan!.id, forceSelected: true);
    await loadMyClan();
  }

  // ==========================
  // EVENTOS DEL CLAN
  // ==========================

  Future<void> createClanEvent({
    required String name,
    required String description,
    required DateTime eventDate,
    required String type,
  }) async {
    if (selectedClan == null) return;
    await _clanService.createClanEvent(
      clanId: selectedClan!.id,
      name: name,
      description: description,
      eventDate: eventDate,
      type: type,
    );
    await loadClanDetail(selectedClan!.id, forceSelected: true);
  }

  // ==========================
  // REALTIME CONFIGURATION
  // ==========================

  void _setupMyClanRealtime() {
    if (myClan == null) return;

    _clanChannel?.unsubscribe();
    _clanChannel = _supabase
        .channel('my_clan_changes_${myClan!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clan_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'clan_id',
            value: myClan!.id,
          ),
          callback: (payload) async {
            debugPrint('Realtime member change detected!');
            final userId = _supabase.auth.currentUser?.id;
            // Si el cambio nos afecta a nosotros directamente (cambio de rol, expulsión)
            if (payload.newRecord['user_id'] == userId || payload.oldRecord['user_id'] == userId) {
              await loadMyClan();
            }
          },
        )
        .subscribe();
  }

  void _setupDetailRealtime(String clanId) {
    _cleanupDetailRealtime();

    _historyChannel = _supabase
        .channel('clan_history_changes_$clanId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'clan_history',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'clan_id',
            value: clanId,
          ),
          callback: (payload) async {
            debugPrint('Realtime history entry inserted!');
            final historyItem = await _clanService.getClanHistory(clanId, offset: 0, limit: 1);
            if (historyItem.isNotEmpty) {
              selectedClanHistory.insert(0, historyItem.first);
              notifyListeners();
            }
          },
        )
        .subscribe();

    _requestsChannel = _supabase
        .channel('clan_requests_changes_$clanId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clan_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'clan_id',
            value: clanId,
          ),
          callback: (payload) async {
            debugPrint('Realtime join request updated!');
            final userId = _supabase.auth.currentUser?.id;
            if (userId != null) {
              myPendingRequest = await _clanService.getMyPendingRequest(clanId);
              // Verificar si el usuario ahora es miembro de este clan
              final member = await _clanService.getClanMember(clanId, userId);
              if (member != null && myClan?.id != clanId) {
                await loadMyClan();
                await loadClanDetail(clanId, forceSelected: true);
                return;
              }
            }
            if (selectedClanMyMemberInfo != null &&
                (selectedClanMyMemberInfo!.role?.canManageMembers == true || selectedClan!.ownerId == userId)) {
              selectedClanRequests = await _clanService.getClanRequests(clanId);
            } else {
              selectedClanRequests = [];
            }
            notifyListeners();
          },
        )
        .subscribe();
  }

  void _cleanupDetailRealtime() {
    _historyChannel?.unsubscribe();
    _historyChannel = null;
    _requestsChannel?.unsubscribe();
    _requestsChannel = null;
  }

  void _cleanupRealtime() {
    _clanChannel?.unsubscribe();
    _clanChannel = null;
    _cleanupDetailRealtime();
  }

  @override
  void dispose() {
    _cleanupRealtime();
    super.dispose();
  }
}
