import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../services/livekit_service.dart';

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
  });

  final String id;
  final String name;
  final String avatarUrl;
  final bool isLocal;
  final bool isMuted;
  final bool isSpeaking;
  final DateTime joinedAt;

  Duration get connectedFor => DateTime.now().toUtc().difference(joinedAt);
}

class VoiceRoomController extends ChangeNotifier {
  VoiceRoomController({LiveKitService? service})
    : _service = service ?? LiveKitService();

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

  bool get isConnected =>
      status == VoiceConnectionStatus.connected ||
      status == VoiceConnectionStatus.reconnecting;
  String? get activeSpeakerId => participants
      .where((participant) => participant.isSpeaking)
      .map((participant) => participant.id)
      .firstOrNull;

  Future<bool> connect(String roomName) async {
    if (status == VoiceConnectionStatus.connecting) return false;
    status = VoiceConnectionStatus.connecting;
    errorMessage = null;
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
    } catch (error) {
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
    return VoiceParticipantState(
      id: participant.identity,
      name: participant.name.trim().isEmpty ? 'Usuario' : participant.name,
      avatarUrl: avatarUrl,
      isLocal: participant == _room?.localParticipant,
      isMuted: !hasActiveMicrophone,
      isSpeaking: participant.isSpeaking,
      joinedAt: participant.joinedAt,
    );
  }

  @override
  void dispose() {
    _durationTicker?.cancel();
    final room = _room;
    if (room != null) room.removeListener(_syncParticipants);
    unawaited(_events?.dispose());
    unawaited(_service.dispose());
    super.dispose();
  }
}
