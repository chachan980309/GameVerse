import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/voice_channel.dart';
import '../services/livekit_service.dart';
import '../services/voice_channel_service.dart';

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
  });

  final String id;
  final String name;
  final String avatarUrl;
  final bool isLocal;
  final bool isMuted;
  final bool isSpeaking;
  final DateTime joinedAt;
  final bool isScreenSharing;

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
    status = VoiceConnectionStatus.connecting;
    errorMessage = null;
    connectedChannel = channel;
    privateCallUser = privateUser;
    isPrivateCall = privateUser != null;
    isMinimized = false;
    notifyListeners();

    try {
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
    return VoiceParticipantState(
      id: participant.identity,
      name: participant.name.trim().isEmpty ? 'Usuario' : participant.name,
      avatarUrl: avatarUrl,
      isLocal: participant == _room?.localParticipant,
      isMuted: !hasActiveMicrophone,
      isSpeaking: participant.isSpeaking,
      joinedAt: participant.joinedAt,
      isScreenSharing: isScreenSharing,
    );
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
}
