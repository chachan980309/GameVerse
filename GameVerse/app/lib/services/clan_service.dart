import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clan_model.dart';
import '../models/clan_member_model.dart';
import '../models/clan_role_model.dart';
import '../models/clan_history_model.dart';
import '../models/clan_request_model.dart';
import '../models/clan_invite_model.dart';
import '../models/clan_event_model.dart';
import '../models/voice_channel.dart';

class ClanService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static final ClanService instance = ClanService._();
  ClanService._();

  static bool hasClansTable = true;

  // ==========================
  // CLAN CRUD
  // ==========================

  Future<List<ClanModel>> getClans({
    int offset = 0,
    int limit = 20,
    String search = '',
    String? filter, // 'official', 'casual', 'competitive', 'my_clans'
    String? region,
    String? language,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      var query = _supabase.from('clans').select();

      if (search.isNotEmpty) {
        query = query.or('name.ilike.%$search%,tag.ilike.%$search%');
      }

      if (region != null && region != 'Todos') {
        query = query.eq('region', region);
      }

      if (language != null && language != 'Todos') {
        query = query.eq('language', language);
      }

      if (filter == 'official') {
        query = query.eq('verified', true);
      } else if (filter == 'casual') {
        query = query.eq('clan_type', 'casual');
      } else if (filter == 'competitive') {
        query = query.eq('clan_type', 'competitive');
      } else if (filter == 'my_clans' && userId != null) {
        // Obtenemos los IDs de clanes a los que pertenece el usuario
        final membersRows = await _supabase
            .from('clan_members')
            .select('clan_id')
            .eq('user_id', userId);
        final clanIds = membersRows.map((r) => r['clan_id'].toString()).toList();
        if (clanIds.isEmpty) return [];
        query = query.inFilter('id', clanIds);
      }

      final rows = await query
          .order('level', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return rows.map((r) => ClanModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error getting clans: $e');
      return [];
    }
  }

  Future<ClanModel?> getClanById(String id) async {
    try {
      final row = await _supabase
          .from('clans')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return ClanModel.fromMap(row);
    } catch (e) {
      debugPrint('Error getting clan by id: $e');
      return null;
    }
  }

  Future<ClanModel?> getMyClan() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final memberRow = await _supabase
          .from('clan_members')
          .select('clan_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (memberRow == null) return null;
      return getClanById(memberRow['clan_id'].toString());
    } catch (e) {
      debugPrint('Error getting my clan: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('relation') || errStr.contains('not found')) {
        hasClansTable = false;
      }
      return null;
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
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final clanData = {
      'name': name,
      'tag': tag.toUpperCase(),
      'description': description,
      'region': region,
      'language': language,
      'visibility': visibility,
      'clan_type': clanType,
      'accent_color': accentColor,
      'owner_id': userId,
      'main_game_id': mainGameId,
    };

    final row = await _supabase
        .from('clans')
        .insert(clanData)
        .select()
        .single();

    final clan = ClanModel.fromMap(row);

    // Crear el canal permanente de voz para el clan
    final roomName = 'clan_voice_${clan.id.replaceAll('-', '')}';
    await _supabase.from('voice_channels').insert({
      'name': '🔊 General - ${clan.name}',
      'room_name': roomName,
      'description': 'Canal de voz permanente del clan ${clan.name}',
      'created_by': userId,
      'clan_id': clan.id,
      'is_featured': false,
      'is_active': true,
    });

    return clan;
  }

  Future<void> updateClan(String id, Map<String, dynamic> data) async {
    await _supabase.from('clans').update(data).eq('id', id);
  }

  Future<void> deleteClan(String id) async {
    await _supabase.from('clans').delete().eq('id', id);
  }

  // ==========================
  // MIEMBROS & ROLES
  // ==========================

  Future<List<ClanMemberModel>> getClanMembers(String clanId) async {
    try {
      final rows = await _supabase
          .from('clan_members')
          .select('''
            *,
            profiles (username, avatar_url),
            clan_roles (
              *,
              clan_permissions (*)
            )
          ''')
          .eq('clan_id', clanId)
          .order('joined_at', ascending: true);

      return rows.map((r) => ClanMemberModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error getting clan members: $e');
      return [];
    }
  }

  Future<ClanMemberModel?> getClanMember(String clanId, String userId) async {
    try {
      final row = await _supabase
          .from('clan_members')
          .select('''
            *,
            profiles (username, avatar_url),
            clan_roles (
              *,
              clan_permissions (*)
            )
          ''')
          .eq('clan_id', clanId)
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return null;
      return ClanMemberModel.fromMap(row);
    } catch (e) {
      debugPrint('Error getting clan member: $e');
      return null;
    }
  }

  Future<List<ClanRoleModel>> getClanRoles(String clanId) async {
    try {
      final rows = await _supabase
          .from('clan_roles')
          .select('*, clan_permissions(*)')
          .eq('clan_id', clanId)
          .order('level', ascending: false);

      return rows.map((r) => ClanRoleModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error getting clan roles: $e');
      return [];
    }
  }

  Future<void> promoteMember(String clanId, String userId, String roleId) async {
    final oldMember = await getClanMember(clanId, userId);
    await _supabase
        .from('clan_members')
        .update({'role_id': roleId})
        .eq('clan_id', clanId)
        .eq('user_id', userId);

    // Obtener información del nuevo rol para el historial
    final roles = await getClanRoles(clanId);
    final newRole = roles.firstWhere((r) => r.id == roleId);

    await logHistory(
      clanId: clanId,
      actionType: 'role_changed',
      metadata: {
        'target_user_id': userId,
        'target_username': oldMember?.username ?? 'Miembro',
        'role_name': newRole.name,
      },
    );
  }

  Future<void> kickMember(String clanId, String userId) async {
    final member = await getClanMember(clanId, userId);
    final actorId = _supabase.auth.currentUser?.id;
    final actorProfile = actorId != null
        ? await _supabase.from('profiles').select('username').eq('id', actorId).maybeSingle()
        : null;
    final actorUsername = actorProfile?['username']?.toString() ?? 'Administrador';

    await _supabase
        .from('clan_members')
        .delete()
        .eq('clan_id', clanId)
        .eq('user_id', userId);

    await logHistory(
      clanId: clanId,
      userId: userId,
      actionType: 'kicked',
      metadata: {
        'username': member?.username ?? 'Miembro',
        'by': actorUsername,
      },
    );
  }

  Future<void> leaveClan(String clanId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final member = await getClanMember(clanId, userId);

    await _supabase
        .from('clan_members')
        .delete()
        .eq('clan_id', clanId)
        .eq('user_id', userId);

    await logHistory(
      clanId: clanId,
      userId: userId,
      actionType: 'left',
      metadata: {'username': member?.username ?? 'Miembro'},
    );
  }

  // ==========================
  // IMÁGENES (STORAGE)
  // ==========================

  Future<String> uploadLogo(String clanId, Uint8List bytes) async {
    final path = '$clanId/logo_${DateTime.now().millisecondsSinceEpoch}.png';
    await _supabase.storage.from('clans').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );

    final publicUrl = _supabase.storage.from('clans').getPublicUrl(path);
    await updateClan(clanId, {'logo_url': path});
    return publicUrl;
  }

  Future<String> uploadBanner(String clanId, Uint8List bytes) async {
    final path = '$clanId/banner_${DateTime.now().millisecondsSinceEpoch}.png';
    await _supabase.storage.from('clans').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );

    final publicUrl = _supabase.storage.from('clans').getPublicUrl(path);
    await updateClan(clanId, {'banner_url': path});
    return publicUrl;
  }

  // ==========================
  // HISTORIAL / ACTIVIDAD
  // ==========================

  Future<List<ClanHistoryModel>> getClanHistory(String clanId, {int offset = 0, int limit = 20}) async {
    try {
      final rows = await _supabase
          .from('clan_history')
          .select('*, profiles(username, avatar_url)')
          .eq('clan_id', clanId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return rows.map((r) => ClanHistoryModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error getting clan history: $e');
      return [];
    }
  }

  Future<void> logHistory({
    required String clanId,
    String? userId,
    required String actionType,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final actorId = userId ?? _supabase.auth.currentUser?.id;
      await _supabase.from('clan_history').insert({
        'clan_id': clanId,
        'user_id': actorId,
        'action_type': actionType,
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint('Error logging history: $e');
    }
  }

  // ==========================
  // SOLICITUDES DE INGRESO
  // ==========================

  Future<List<ClanRequestModel>> getClanRequests(String clanId) async {
    try {
      final rows = await _supabase
          .from('clan_requests')
          .select('*, profiles(username, avatar_url)')
          .eq('clan_id', clanId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return rows.map((r) => ClanRequestModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error getting clan requests: $e');
      return [];
    }
  }

  Future<void> createClanRequest(String clanId, String message) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('clan_requests').insert({
      'clan_id': clanId,
      'user_id': userId,
      'message': message,
      'status': 'pending',
    });
  }

  Future<void> updateClanRequestStatus(String requestId, String clanId, String status) async {
    final requestRow = await _supabase
        .from('clan_requests')
        .update({'status': status})
        .eq('id', requestId)
        .select()
        .single();

    final targetUserId = requestRow['user_id'].toString();

    if (status == 'accepted') {
      final roles = await getClanRoles(clanId);
      final memberRole = roles.firstWhere((r) => r.name == 'Member');

      await _supabase.from('clan_members').insert({
        'clan_id': clanId,
        'user_id': targetUserId,
        'role_id': memberRole.id,
      });

      final profile = await _supabase.from('profiles').select('username').eq('id', targetUserId).single();
      final username = profile['username']?.toString() ?? 'Miembro';

      await logHistory(
        clanId: clanId,
        userId: targetUserId,
        actionType: 'joined',
        metadata: {'username': username},
      );
    }
  }

  // ==========================
  // INVITACIONES
  // ==========================

  Future<List<ClanInviteModel>> getMyInvites() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final rows = await _supabase
          .from('clan_invites')
          .select('''
            *,
            clans (name, logo_url),
            inviter:profiles!inviter_id (username)
          ''')
          .eq('invitee_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return rows.map((r) => ClanInviteModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error getting my invites: $e');
      return [];
    }
  }

  Future<void> createClanInvite(String clanId, String inviteeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('clan_invites').insert({
      'clan_id': clanId,
      'invitee_id': inviteeId,
      'inviter_id': userId,
      'status': 'pending',
    });
  }

  Future<void> updateClanInviteStatus(String inviteId, String clanId, String status) async {
    final inviteRow = await _supabase
        .from('clan_invites')
        .update({'status': status})
        .eq('id', inviteId)
        .select()
        .single();

    final inviteeId = inviteRow['invitee_id'].toString();

    if (status == 'accepted') {
      final roles = await getClanRoles(clanId);
      final memberRole = roles.firstWhere((r) => r.name == 'Member');

      await _supabase.from('clan_members').insert({
        'clan_id': clanId,
        'user_id': inviteeId,
        'role_id': memberRole.id,
      });

      final profile = await _supabase.from('profiles').select('username').eq('id', inviteeId).single();
      final username = profile['username']?.toString() ?? 'Miembro';

      await logHistory(
        clanId: clanId,
        userId: inviteeId,
        actionType: 'joined',
        metadata: {'username': username},
      );
    }
  }

  // ==========================
  // EVENTOS DEL CLAN
  // ==========================

  Future<List<ClanEventModel>> getClanEvents(String clanId) async {
    try {
      final rows = await _supabase
          .from('clan_events')
          .select('*, profiles(username)')
          .eq('clan_id', clanId)
          .order('event_date', ascending: true);

      return rows.map((r) => ClanEventModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error getting clan events: $e');
      return [];
    }
  }

  Future<ClanEventModel> createClanEvent({
    required String clanId,
    required String name,
    required String description,
    required DateTime eventDate,
    required String type,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final row = await _supabase
        .from('clan_events')
        .insert({
          'clan_id': clanId,
          'name': name,
          'description': description,
          'event_date': eventDate.toUtc().toIso8601String(),
          'type': type,
          'creator_id': userId,
        })
        .select()
        .single();

    final event = ClanEventModel.fromMap({
      ...row,
      'profiles': {'username': 'Tú'},
    });

    await logHistory(
      clanId: clanId,
      actionType: 'event_created',
      metadata: {'event_name': event.name},
    );

    // Premiamos al clan con 50 XP por crear eventos
    await awardClanXP(clanId, 50);

    return event;
  }

  Future<void> deleteClanEvent(String clanId, String eventId) async {
    await _supabase.from('clan_events').delete().eq('id', eventId);
  }

  // ==========================
  // SISTEMA DE PROGRESIÓN (XP & LEVELS)
  // ==========================

  Future<void> awardClanXP(String clanId, int amount) async {
    try {
      final clan = await getClanById(clanId);
      if (clan == null) return;

      final newXp = clan.experience + amount;
      // Cada nivel requiere 1000 XP
      final newLevel = (newXp / 1000).floor() + 1;

      final updates = {
        'experience': newXp,
      };

      if (newLevel > clan.level) {
        updates['level'] = newLevel;
      }

      await updateClan(clanId, updates);

      if (newLevel > clan.level) {
        await logHistory(
          clanId: clanId,
          actionType: 'level_up',
          metadata: {'level': newLevel},
        );
      }
    } catch (e) {
      debugPrint('Error awarding clan XP: $e');
    }
  }

  // ==========================
  // CANAL DE VOZ DEL CLAN
  // ==========================

  Future<VoiceChannel?> getClanVoiceChannel(String clanId) async {
    try {
      var row = await _supabase
          .from('voice_channels')
          .select()
          .eq('clan_id', clanId)
          .maybeSingle();

      if (row == null) {
        // Self-healing: si no existe el canal de voz del clan, lo creamos dinámicamente en caliente
        final clan = await getClanById(clanId);
        if (clan != null) {
          final userId = _supabase.auth.currentUser?.id;
          if (userId != null) {
            final roomName = 'clan_voice_${clan.id.replaceAll('-', '')}';
            final newRow = await _supabase.from('voice_channels').insert({
              'name': '🔊 General - ${clan.name}',
              'room_name': roomName,
              'description': 'Canal de voz permanente del clan ${clan.name}',
              'created_by': userId,
              'clan_id': clan.id,
              'is_featured': false,
              'is_active': true,
            }).select().single();
            
            row = newRow;
          }
        }
      }

      if (row == null) return null;
      return VoiceChannel.fromMap(row);
    } catch (e) {
      debugPrint('Error getting clan voice channel: $e');
      return null;
    }
  }
}
