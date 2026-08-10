import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/voice_channel.dart';
import '../services/livekit_service.dart';
import '../services/voice_channel_service.dart';
import 'profile_controller.dart';

enum VoiceConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class VoiceParticipantState {
  const VoiceParticipantState({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.isLocal,
    required this.isMuted,
    required this.isSpeaking,
    required this.joinedAt,
    required this.isScreenSharing,
    this.localVolume = 1.0,
    this.isLocalMuted = false,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final bool isLocal;
  final bool isMuted;
  final bool isSpeaking;
  final DateTime joinedAt;
  final bool isScreenSharing;
  final double localVolume;
  final bool isLocalMuted;

  Duration get connectedFor => DateTime.now().toUtc().difference(joinedAt);
}

class VoiceRoomController extends ChangeNotifier {
  static final VoiceRoomController instance = VoiceRoomController._internal();

  factory VoiceRoomController({LiveKitService? service}) => instance;

  VoiceRoomController._internal() : _service = LiveKitService();

  final LiveKitService _service;
  EventsListener<RoomEvent>? _events;
  Timer? _durationTicker;
  Room? _room;

  VoiceConnectionStatus status = VoiceConnectionStatus.disconnected;

  // Variables de Configuración de Audio Persistente
  String noiseSuppressionMode = 'standard'; // 'off', 'standard', 'ai'
  bool echoCancellationEnabled = true;
  bool autoGainControlEnabled = false;
  List<VoiceParticipantState> participants = const [];
  String? errorMessage;
  bool microphoneMuted = false;
  bool speakerEnabled = false;
  bool deafened = false;
  bool pushToTalkEnabled = false;
  bool isScreenSharing = false;
  VoiceChannel? connectedChannel;
  String? get connectedChannelId => connectedChannel?.id;
  Map<String, dynamic>? privateCallUser;
  bool isPrivateCall = false;
  bool isMinimized = false;
  DateTime? joinedAt;

  String get durationFormatted {
    final joined = joinedAt;
    if (joined == null) return '00:00';
    final duration = DateTime.now().difference(joined);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get isConnected =>
      status == VoiceConnectionStatus.connected ||
      status == VoiceConnectionStatus.reconnecting;
  String? get activeSpeakerId => participants
      .where((participant) => participant.isSpeaking)
      .map((participant) => participant.id)
      .firstOrNull;

  VideoTrack? get remoteScreenShareTrack {
    final room = _room;
    if (room == null) return null;
    for (final participant in room.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        final track = pub.track;
        if (track != null && !pub.muted) {
          if (pub is RemoteTrackPublication && pub.subscribed) {
            pub.setVideoQuality(VideoQuality.HIGH);
          }
          return track as VideoTrack;
        }
      }
    }
    return null;
  }

  void minimize() {
    isMinimized = true;
    notifyListeners();
  }

  void maximize() {
    isMinimized = false;
    notifyListeners();
  }

  Future<bool> connect(String roomName, {VoiceChannel? channel, Map<String, dynamic>? privateUser}) async {
    if (status == VoiceConnectionStatus.connecting) return false;

    // Leave previous channel first if we are connected to one!
    if (isConnected) {
      await leaveRoom();
    }

    status = VoiceConnectionStatus.connecting;
    errorMessage = null;
    connectedChannel = channel;
    privateCallUser = privateUser;
    isPrivateCall = privateUser != null;
    isMinimized = false;
    notifyListeners();

    try {
      await loadSettings(); // Cargar configuraciones guardadas de audio
      final room = await _service.connect(roomName);
      _room = room;
      room.addListener(_syncParticipants);
      _events = room.createListener()
        ..on<RoomReconnectingEvent>((_) {
          status = VoiceConnectionStatus.reconnecting;
          notifyListeners();
        })
        ..on<RoomResumingEvent>((_) {
          status = VoiceConnectionStatus.reconnecting;
          notifyListeners();
        })
        ..on<RoomReconnectedEvent>((_) {
          status = VoiceConnectionStatus.connected;
          errorMessage = null;
          _syncParticipants();
        })
        ..on<RoomDisconnectedEvent>((event) {
          status = VoiceConnectionStatus.disconnected;
          participants = const [];
          notifyListeners();
        })
        ..on<TrackSubscribedEvent>((event) {
          if (event.track is RemoteAudioTrack) {
            _applyParticipantVolume(event.participant.identity);
          }
        });
      status = VoiceConnectionStatus.connected;
      joinedAt = DateTime.now();
      microphoneMuted =
          !(room.localParticipant?.isMicrophoneEnabled() ?? false);
      speakerEnabled = _service.speakerEnabled;
      _durationTicker?.cancel();
      _durationTicker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => notifyListeners(),
      );
      _syncParticipants();
      return true;
    } catch (error, stack) {
      print("[CALL] EXCEPCIÓN DETECTADA EN VOICE ROOM CONTROLLER: $error");
      print(stack.toString());
      status = VoiceConnectionStatus.error;
      errorMessage = error is LiveKitServiceException
          ? error.message
          : 'No se pudo entrar al canal de voz.';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() => leaveRoom();

  Future<void> leaveRoom() async {
    _durationTicker?.cancel();
    _durationTicker = null;
    final room = _room;
    _room = null;
    if (room != null) room.removeListener(_syncParticipants);
    await _events?.dispose();
    _events = null;

    final channelId = connectedChannel?.id;
    if (channelId != null) {
      try {
        await VoiceChannelService().leaveChannel(channelId);
      } catch (e) {
        print("Error leaving channel $channelId in DB: $e");
      }
    }

    await _service.leaveRoom();
    status = VoiceConnectionStatus.disconnected;
    participants = const [];
    microphoneMuted = false;
    deafened = false;
    isScreenSharing = false;
    connectedChannel = null;
    privateCallUser = null;
    isPrivateCall = false;
    isMinimized = false;
    joinedAt = null;

    _trackSelfInVoicePresence();

    notifyListeners();
  }

  Future<void> toggleMicrophone() async {
    try {
      final enabled = await _service.toggleMicrophone();
      microphoneMuted = !enabled;
      _syncParticipants();
    } catch (_) {
      errorMessage = 'No se pudo cambiar el estado del micrófono.';
      notifyListeners();
    }
  }

  Future<void> toggleMute() => toggleMicrophone();

  Future<bool> toggleScreenShare() async {
    try {
      final enabled = await _service.toggleScreenShare();
      isScreenSharing = enabled;
      notifyListeners();
      return enabled;
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (!message.contains('cancel') && !message.contains('abort') &&
          !message.contains('dismissed') && !message.contains('notallowed')) {
        errorMessage = 'No se pudo iniciar la transmisión de pantalla.';
        notifyListeners();
      }
      isScreenSharing = _service.isScreenSharing;
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleSpeaker() async {
    try {
      speakerEnabled = await _service.toggleSpeaker();
      notifyListeners();
    } catch (_) {
      errorMessage = 'No se pudo cambiar la salida de audio.';
      notifyListeners();
    }
  }

  Future<void> toggleDeafen() async {
    if (!deafened && !_service.canPlaybackAudio) {
      final playbackStarted = await _service.startAudioPlayback();
      if (!playbackStarted) {
        errorMessage =
            'Chrome bloqueó el audio. Pulsa nuevamente el botón de audífonos.';
      } else {
        errorMessage = null;
      }
      notifyListeners();
      return;
    }
    deafened = !deafened;
    await _service.setRemoteAudioEnabled(!deafened);
    notifyListeners();
  }

  void setPushToTalkEnabled(bool enabled) {
    pushToTalkEnabled = enabled;
    notifyListeners();
  }

  Future<void> beginPushToTalk() async {
    if (!pushToTalkEnabled || !microphoneMuted) return;
    await toggleMicrophone();
  }

  Future<void> endPushToTalk() async {
    if (!pushToTalkEnabled || microphoneMuted) return;
    await toggleMicrophone();
  }

  Future<List<MediaDevice>> audioInputs() => _service.audioInputs();
  Future<List<MediaDevice>> audioOutputs() => _service.audioOutputs();
  Future<void> selectAudioInput(MediaDevice device) =>
      _service.selectAudioInput(device);
  Future<void> selectAudioOutput(MediaDevice device) =>
      _service.selectAudioOutput(device);

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  RealtimeChannel? _voicePresenceChannel;
  Map<String, List<VoiceChannelMember>> voicePresenceParticipants = {};
  int presenceRevision = 0;
  Map<String, dynamic>? _lastPresencePayload;

  void initVoicePresence() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    if (_voicePresenceChannel != null) return;

    _voicePresenceChannel = Supabase.instance.client.channel('global-voice-presence');
    _voicePresenceChannel!.onPresenceSync((payload) {
      _syncVoicePresenceState();
    }).subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _trackSelfInVoicePresence();
      }
    });
  }

  void stopVoicePresence() {
    final channel = _voicePresenceChannel;
    _voicePresenceChannel = null;
    if (channel != null) {
      channel.untrack();
      Supabase.instance.client.removeChannel(channel);
    }
    voicePresenceParticipants.clear();
    _lastPresencePayload = null;
    notifyListeners();
  }

  void _trackSelfInVoicePresence() {
    final channel = _voicePresenceChannel;
    if (channel == null) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final profile = ProfileController.instance;
    final username = profile.username.isNotEmpty ? profile.username : (Supabase.instance.client.auth.currentUser?.email?.split('@').first ?? 'Usuario');
    final avatarUrl = profile.avatarUrl ?? '';

    final channelId = connectedChannel?.id;
    
    bool isSpeaking = false;
    if (_room != null && _room!.localParticipant != null) {
      isSpeaking = _room!.localParticipant!.isSpeaking;
    }

    final newPayload = {
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'channel_id': channelId,
      'muted': microphoneMuted,
      'speaking': isSpeaking,
      'screen_sharing': isScreenSharing,
    };

    if (_lastPresencePayload != null &&
        _lastPresencePayload!['channel_id'] == newPayload['channel_id'] &&
        _lastPresencePayload!['muted'] == newPayload['muted'] &&
        _lastPresencePayload!['speaking'] == newPayload['speaking'] &&
        _lastPresencePayload!['screen_sharing'] == newPayload['screen_sharing'] &&
        _lastPresencePayload!['username'] == newPayload['username'] &&
        _lastPresencePayload!['avatar_url'] == newPayload['avatar_url']) {
      return;
    }

    _lastPresencePayload = newPayload;
    channel.track(newPayload);
  }

  void _syncVoicePresenceState() {
    final channel = _voicePresenceChannel;
    if (channel == null) return;

    final state = channel.presenceState();
    final Map<String, List<VoiceChannelMember>> updatedPresence = {};

    for (final singlePresence in state) {
      final presences = singlePresence.presences;
      for (final presence in presences) {
        final payload = presence.payload;
        if (payload != null && payload['user_id'] != null && payload['channel_id'] != null) {
          final chId = payload['channel_id'].toString();
          final uId = payload['user_id'].toString();
          final uname = payload['username']?.toString() ?? 'Usuario';
          final avatar = payload['avatar_url']?.toString() ?? '';
          final muted = payload['muted'] == true;
          final speaking = payload['speaking'] == true;
          final screenSharing = payload['screen_sharing'] == true;

          final member = VoiceChannelMember(
            userId: uId,
            username: uname,
            avatarUrl: avatar,
            isMuted: muted,
            isSpeaking: speaking,
            isScreenSharing: screenSharing,
          );

          updatedPresence.putIfAbsent(chId, () => []).add(member);
        }
      }
    }

    presenceRevision++;
    voicePresenceParticipants = updatedPresence;
    notifyListeners();
  }

  RealtimeChannel? _callSubscription;
  bool isOutgoingRinging = false;
  bool isIncomingRinging = false;
  Map<String, dynamic>? activePrivateCallRow;
  Map<String, dynamic>? callingUserProfile;

  void listenToPrivateCalls() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _callSubscription?.unsubscribe();
    _callSubscription = Supabase.instance.client
        .channel('private-calls-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'voice_channels',
          callback: (payload) {
            final row = payload.newRecord;
            final oldRow = payload.oldRecord;
            final eventType = payload.eventType;

            _handleCallEvent(eventType, row, oldRow);
          },
        )
        .subscribe();
  }

  void _handleCallEvent(PostgresChangeEvent eventType, Map<String, dynamic> row, Map<String, dynamic>? oldRow) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    if (eventType == PostgresChangeEvent.insert) {
      if (row['is_private'] == true && row['invitee_id'] == userId && row['private_status'] == 'ringing') {
        isIncomingRinging = true;
        activePrivateCallRow = row;
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', row['created_by'])
              .single();
          callingUserProfile = profile;
        } catch (_) {
          callingUserProfile = {
            'id': row['created_by'],
            'username': 'Usuario',
          };
        }
        notifyListeners();
      }
    } else if (eventType == PostgresChangeEvent.update) {
      final channelId = row['id'];
      if (channelId == activePrivateCallRow?['id']) {
        final status = row['private_status'];
        if (row['created_by'] == userId) {
          // Nosotros somos el creador/que llama
          if (status == 'accepted') {
            print("[STEP 9-CALLER] Recibido evento 'accepted' vía Realtime.");
            isOutgoingRinging = false;
            activePrivateCallRow = row;
            notifyListeners();
          } else if (status == 'rejected' || status == 'ended') {
            isOutgoingRinging = false;
            activePrivateCallRow = null;
            callingUserProfile = null;
            notifyListeners();
            await leaveRoom();
          }
        } else if (row['invitee_id'] == userId) {
          // Nosotros somos el receptor
          if (status == 'ended' || status == 'rejected') {
            isIncomingRinging = false;
            activePrivateCallRow = null;
            callingUserProfile = null;
            notifyListeners();
            await leaveRoom();
          }
        }
      }
    } else if (eventType == PostgresChangeEvent.delete) {
      final oldId = oldRow?['id']?.toString();
      if (oldId != null && oldId == activePrivateCallRow?['id']?.toString()) {
        isIncomingRinging = false;
        isOutgoingRinging = false;
        activePrivateCallRow = null;
        callingUserProfile = null;
        notifyListeners();
        await leaveRoom();
      }
    }
  }

  Future<void> startPrivateCall(Map<String, dynamic> receiverProfile) async {
    print("[STEP 2] Entrando a startPrivateCall en VoiceRoomController");
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print("[STEP 2] Error: Usuario no autenticado.");
      return;
    }

    // Si ya estamos en una llamada, colgar primero
    if (isConnected) {
      print("[STEP 2] Ya hay llamada conectada; colgando primero...");
      await leaveRoom();
    }

    final roomName = 'private_${userId.replaceAll('-', '')}_${receiverProfile['id'].toString().replaceAll('-', '')}';
    
    // LOGS ANTES DEL INSERT
    print("[LOG-BEFORE-INSERT] Iniciando inserción de llamada privada:");
    print("  - room_name: $roomName");
    print("  - caller_id (created_by): $userId");
    print("  - invitee_id: ${receiverProfile['id']}");

    isOutgoingRinging = true;
    callingUserProfile = receiverProfile;
    notifyListeners();

    try {
      final row = await Supabase.instance.client.from('voice_channels').insert({
        'name': 'Llamada privada',
        'room_name': roomName,
        'description': 'private_call',
        'created_by': userId,
        'is_private': true,
        'invitee_id': receiverProfile['id'],
        'private_status': 'ringing',
        'is_active': true,
      }).select().single();
      
      // LOGS DESPUÉS DEL INSERT
      print("[LOG-AFTER-INSERT] Canal privado insertado con éxito!");
      print("  - fila completa devuelta por Supabase: $row");

      activePrivateCallRow = row;
      notifyListeners();

      // Unirse al canal en la base de datos
      await VoiceChannelService().joinChannel(row['id']);

      // Conectarse a Livekit inmediatamente
      final voiceChannel = VoiceChannel.fromMap(row);
      await connect(roomName, channel: voiceChannel, privateUser: receiverProfile);
    } catch (e, stack) {
      print("[STEP 4-ERROR] Error al iniciar la llamada: $e");
      print(stack.toString());
      isOutgoingRinging = false;
      callingUserProfile = null;
      errorMessage = 'No se pudo iniciar la llamada: $e';
      notifyListeners();
    }
  }

  Future<void> acceptPrivateCall() async {
    if (activePrivateCallRow == null) {
      print("[LOG-ACCEPT] Error: activePrivateCallRow es null al intentar aceptar.");
      return;
    }
    isIncomingRinging = false;
    notifyListeners();

    final searchId = activePrivateCallRow!['id'];
    final searchRoomName = activePrivateCallRow!['room_name'];
    print("[LOG-ACCEPT-BEFORE] Intentando actualizar el canal de voz para aceptar:");
    print("  - Consulta SQL equivalente: UPDATE voice_channels SET private_status = 'accepted' WHERE id = '$searchId' RETURNING *;");
    print("  - room_name buscado (desde el registro activo): $searchRoomName");
    print("  - ID del canal buscado: $searchId");

    try {
      // Intentar primero hacer un select para ver si el canal sigue existiendo antes de actualizar (ayuda a diagnosticar)
      final checkRows = await Supabase.instance.client
          .from('voice_channels')
          .select()
          .eq('id', searchId);
      
      print("  - Cantidad de filas encontradas en SELECT previo: ${checkRows.length}");
      if (checkRows.isNotEmpty) {
        print("  - Fila encontrada en SELECT previo: ${checkRows.first}");
      } else {
        print("  - ADVERTENCIA: ¡No se encontró ninguna fila con ese ID en SELECT previo!");
      }

      final row = await Supabase.instance.client
          .from('voice_channels')
          .update({'private_status': 'accepted'})
          .eq('id', searchId)
          .select()
          .single();

      print("[LOG-ACCEPT-AFTER] Actualización exitosa!");
      print("  - Fila actualizada devuelta: $row");

      activePrivateCallRow = row;
      notifyListeners();

      // Unirse al canal en la base de datos
      await VoiceChannelService().joinChannel(row['id']);

      // Conectarse a Livekit
      final voiceChannel = VoiceChannel.fromMap(row);
      await connect(row['room_name'], channel: voiceChannel, privateUser: callingUserProfile);
    } catch (e) {
      print("[LOG-ACCEPT-ERROR] Excepción capturada en acceptPrivateCall: $e");
      activePrivateCallRow = null;
      callingUserProfile = null;
      errorMessage = 'No se pudo aceptar la llamada: $e';
      notifyListeners();
    }
  }

  Future<void> rejectPrivateCall() async {
    if (activePrivateCallRow == null) return;
    isIncomingRinging = false;
    final rowId = activePrivateCallRow!['id'];
    activePrivateCallRow = null;
    callingUserProfile = null;
    notifyListeners();

    try {
      await Supabase.instance.client
          .from('voice_channels')
          .update({'private_status': 'rejected'})
          .eq('id', rowId);
    } catch (_) {}
    await leaveRoom();
  }

  Future<void> endPrivateCall() async {
    isOutgoingRinging = false;
    isIncomingRinging = false;
    final rowId = activePrivateCallRow?['id'] ?? connectedChannel?.id;
    activePrivateCallRow = null;
    callingUserProfile = null;
    notifyListeners();

    if (rowId != null) {
      try {
        await VoiceChannelService().leaveChannel(rowId);
      } catch (_) {}
      try {
        await Supabase.instance.client
            .from('voice_channels')
            .update({'private_status': 'ended'})
            .eq('id', rowId);
      } catch (_) {}
    }
    await leaveRoom();
  }

  final Map<String, double> _participantVolumes = {};
  final Map<String, bool> _participantLocalMutes = {};
  final Map<String, double> _screenVolumes = {};
  final Map<String, bool> _screenLocalMutes = {};

  void _syncParticipants() {
    final room = _room;
    if (room == null) return;
    final all = <Participant>[
      ?room.localParticipant,
      ...room.remoteParticipants.values,
    ];
    participants = all.map(_participantState).toList()
      ..sort((a, b) {
        if (a.isLocal != b.isLocal) return a.isLocal ? -1 : 1;
        if (a.isSpeaking != b.isSpeaking) return a.isSpeaking ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    microphoneMuted = !(room.localParticipant?.isMicrophoneEnabled() ?? false);
    _trackSelfInVoicePresence();
    notifyListeners();
  }

  VoiceParticipantState _participantState(Participant participant) {
    var avatarUrl = '';
    final metadata = participant.metadata;
    if (metadata != null && metadata.isNotEmpty) {
      try {
        final decoded = jsonDecode(metadata);
        if (decoded is Map) avatarUrl = decoded['avatarUrl']?.toString() ?? '';
      } catch (_) {
        // Metadata de otro cliente: el avatar queda vacío.
      }
    }
    final audioPublications = participant.audioTrackPublications;
    final hasActiveMicrophone = audioPublications.any(
      (publication) => !publication.muted,
    );
    final isScreenSharing = participant.videoTrackPublications.isNotEmpty;
    final localVolume = _participantVolumes[participant.identity] ?? 1.0;
    final isLocalMuted = _participantLocalMutes[participant.identity] ?? false;

    return VoiceParticipantState(
      id: participant.identity,
      name: participant.name.trim().isEmpty ? 'Usuario' : participant.name,
      avatarUrl: avatarUrl,
      isLocal: participant == _room?.localParticipant,
      isMuted: !hasActiveMicrophone,
      isSpeaking: participant.isSpeaking,
      joinedAt: participant.joinedAt,
      isScreenSharing: isScreenSharing,
      localVolume: localVolume,
      isLocalMuted: isLocalMuted,
    );
  }

  double getParticipantVolume(String participantId) => _participantVolumes[participantId] ?? 1.0;
  bool isParticipantLocalMuted(String participantId) => _participantLocalMutes[participantId] ?? false;

  void setParticipantVolume(String participantId, double volume) {
    _participantVolumes[participantId] = volume;
    _applyParticipantVolume(participantId);
    _syncParticipants();
    saveParticipantSettings();
  }

  void toggleParticipantLocalMute(String participantId) {
    final currentlyMuted = _participantLocalMutes[participantId] ?? false;
    _participantLocalMutes[participantId] = !currentlyMuted;
    _applyParticipantVolume(participantId);
    _syncParticipants();
    saveParticipantSettings();
  }

  double getScreenVolume(String participantId) => _screenVolumes[participantId] ?? 1.0;
  bool isScreenLocalMuted(String participantId) => _screenLocalMutes[participantId] ?? false;

  void setScreenVolume(String participantId, double volume) {
    _screenVolumes[participantId] = volume;
    _applyParticipantVolume(participantId);
    _syncParticipants();
  }

  void toggleScreenLocalMute(String participantId) {
    final currentlyMuted = _screenLocalMutes[participantId] ?? false;
    _screenLocalMutes[participantId] = !currentlyMuted;
    _applyParticipantVolume(participantId);
    _syncParticipants();
  }

  void _applyParticipantVolume(String participantId) {
    final room = _room;
    if (room == null) return;
    
    RemoteParticipant? participant;
    for (final p in room.remoteParticipants.values) {
      if (p.identity == participantId) {
        participant = p;
        break;
      }
    }
    
    if (participant == null) return;
    
    final isMuted = _participantLocalMutes[participantId] ?? false;
    final volume = isMuted ? 0.0 : (_participantVolumes[participantId] ?? 1.0);
    
    for (final publication in participant.audioTrackPublications) {
      final track = publication.track;
      if (track is RemoteAudioTrack) {
        if (publication.source == TrackSource.screenShareAudio) {
          final isScreenMuted = _screenLocalMutes[participantId] ?? false;
          final screenVol = isScreenMuted ? 0.0 : (_screenVolumes[participantId] ?? 1.0);
          final finalVol = kIsWeb ? screenVol.clamp(0.0, 1.0) : screenVol;
          
          // Habilitar/Deshabilitar track a nivel de WebRTC para un silencio absoluto garantizado
          track.mediaStreamTrack.enabled = (finalVol > 0.0);
          
          if (kIsWeb) {
            try {
              js.context.callMethod('eval', [
                """
                (function() {
                  var audios = document.querySelectorAll('audio');
                  for (var i = 0; i < audios.length; i++) {
                    var audio = audios[i];
                    if (audio.srcObject) {
                      var tracks = audio.srcObject.getAudioTracks();
                      if (tracks.length > 0 && tracks[0].id === '${track.mediaStreamTrack.id}') {
                        audio.volume = $finalVol;
                      }
                    }
                  }
                })()
                """
              ]);
            } catch (e) {
              print("Error setting web volume via JS: $e");
            }
          } else {
            rtc.Helper.setVolume(finalVol, track.mediaStreamTrack);
          }
        } else {
          final finalVol = kIsWeb ? volume.clamp(0.0, 1.0) : volume;
          
          // Habilitar/Deshabilitar track a nivel de WebRTC para un silencio absoluto garantizado
          track.mediaStreamTrack.enabled = (finalVol > 0.0);
          
          if (kIsWeb) {
            try {
              js.context.callMethod('eval', [
                """
                (function() {
                  var audios = document.querySelectorAll('audio');
                  for (var i = 0; i < audios.length; i++) {
                    var audio = audios[i];
                    if (audio.srcObject) {
                      var tracks = audio.srcObject.getAudioTracks();
                      if (tracks.length > 0 && tracks[0].id === '${track.mediaStreamTrack.id}') {
                        audio.volume = $finalVol;
                      }
                    }
                  }
                })()
                """
              ]);
            } catch (e) {
              print("Error setting web volume via JS: $e");
            }
          } else {
            rtc.Helper.setVolume(finalVol, track.mediaStreamTrack);
          }
        }
      }
    }
  }

  /// Limpieza completa al cerrar la app. No llamar desde dispose() de una página.
  Future<void> shutdown() async {
    _durationTicker?.cancel();
    final room = _room;
    if (room != null) room.removeListener(_syncParticipants);
    await _events?.dispose();
    await _service.dispose();
  }

  @override
  void dispose() {
    // El singleton NO debe destruirse al hacer pop de una página.
    // La conexión de voz sigue activa mientras el usuario no salga manualmente.
    super.dispose();
  }

  // ==========================================
  // CONFIGURACIÓN PERSISTENTE EN TIEMPO REAL
  // ==========================================

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    noiseSuppressionMode = prefs.getString('noise_suppression_mode') ?? 'standard';
    echoCancellationEnabled = prefs.getBool('echo_cancellation_enabled') ?? true;
    autoGainControlEnabled = prefs.getBool('auto_gain_control_enabled') ?? false;
    
    // Cargar volúmenes de participantes guardados
    final volsJson = prefs.getString('participant_volumes_saved');
    if (volsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(volsJson);
        decoded.forEach((key, val) {
          _participantVolumes[key] = (val as num).toDouble();
        });
      } catch (_) {}
    }
    
    final mutesJson = prefs.getString('participant_mutes_saved');
    if (mutesJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(mutesJson);
        decoded.forEach((key, val) {
          _participantLocalMutes[key] = val as bool;
        });
      } catch (_) {}
    }
  }

  Future<void> saveParticipantSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('participant_volumes_saved', jsonEncode(_participantVolumes));
    await prefs.setString('participant_mutes_saved', jsonEncode(_participantLocalMutes));
  }

  Future<void> setNoiseSuppressionMode(String mode) async {
    noiseSuppressionMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('noise_suppression_mode', mode);
    await _applyAudioCaptureOptions();
    notifyListeners();
  }

  Future<void> toggleEchoCancellation() async {
    echoCancellationEnabled = !echoCancellationEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('echo_cancellation_enabled', echoCancellationEnabled);
    await _applyAudioCaptureOptions();
    notifyListeners();
  }

  Future<void> toggleAutoGainControl() async {
    autoGainControlEnabled = !autoGainControlEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_gain_control_enabled', autoGainControlEnabled);
    await _applyAudioCaptureOptions();
    notifyListeners();
  }

  Future<void> _applyAudioCaptureOptions() async {
    final room = _room;
    if (room == null) return;
    
    final localPart = room.localParticipant;
    if (localPart == null) return;

    for (final pub in localPart.audioTrackPublications) {
      final track = pub.track;
      if (track is LocalAudioTrack) {
        bool echo = echoCancellationEnabled;
        bool ns = true;
        bool agc = autoGainControlEnabled;

        if (noiseSuppressionMode == 'off') {
          echo = false;
          ns = false;
          agc = false;
        } else if (noiseSuppressionMode == 'standard') {
          ns = true;
        } else if (noiseSuppressionMode == 'ai') {
          ns = true; // El modo avanzado aprovecha los algoritmos nativos más agresivos
        }

        try {
          await track.mediaStreamTrack.applyConstraints({
            'echoCancellation': echo,
            'noiseSuppression': ns,
            'autoGainControl': agc,
          });
          print("[IA-AUDIO] Constraints aplicadas en tiempo real con éxito: echo=$echo, ns=$ns, agc=$agc");
        } catch (e) {
          print("[IA-AUDIO] Error aplicando constraints en tiempo real: $e");
        }
      }
    }
  }
}
