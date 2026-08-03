import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveKitService {
  LiveKitService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  Room? _room;

  Room? get room => _room;
  bool get microphoneEnabled =>
      _room?.localParticipant?.isMicrophoneEnabled() ?? false;
  bool get speakerEnabled => AudioManager.instance.isSpeakerOutputPreferred;
  bool get canPlaybackAudio => _room?.canPlaybackAudio ?? false;
  bool get isScreenSharing =>
      _room?.localParticipant?.isScreenShareEnabled() ?? false;

  Future<Room> connect(String roomName) async {
    final user = _supabase.auth.currentUser;
    final session = _supabase.auth.currentSession;
    if (user == null || session == null) {
      throw const LiveKitServiceException(
        'Debes iniciar sesión para entrar al canal.',
      );
    }

    await leaveRoom();
    final profile = await _supabase
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .maybeSingle();
    final username = profile?['username']?.toString().trim();

    try {
      final response = await _supabase.functions.invoke(
        'livekit-token',
        body: {
          'room': roomName,
          'userId': user.id,
          'username': username?.isNotEmpty == true
              ? username
              : (user.email ?? 'Usuario'),
        },
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final token = data['token']?.toString() ?? '';
      final url = data['url']?.toString() ?? '';
      final tokenParts = token.split('.').length;
      final urlScheme = Uri.tryParse(url)?.scheme;
      debugPrint(
        'LiveKit credentials received: '
        'tokenParts=$tokenParts, urlScheme=$urlScheme',
      );
      if (tokenParts != 3 || urlScheme != 'wss') {
        throw const LiveKitServiceException(
          'La respuesta de LiveKit no es válida.',
        );
      }

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: false,
          dynacast: false,
          defaultAudioPublishOptions: AudioPublishOptions(
            encoding: AudioEncoding(maxBitrate: 128000),
          ),
          defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
            params: VideoParametersPresets.screenShareH1080FPS30,
            captureScreenAudio: true,
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: false,
            videoEncoding: VideoEncoding(
              maxBitrate: 6000000,
              maxFramerate: 30,
            ),
          ),
        ),
      );
      _room = room;
      await room.prepareConnection(url, token);
      await room.connect(url, token);
      await room.startAudio();
      final publication = await room.localParticipant?.setMicrophoneEnabled(
        true,
      );
      debugPrint(
        'LiveKit audio ready: playback=${room.canPlaybackAudio}, '
        'microphonePublished=${publication != null}',
      );
      return room;
    } on FunctionException catch (error) {
      await leaveRoom();
      throw LiveKitServiceException(
        error.status == 401
            ? 'Tu sesión expiró. Inicia sesión nuevamente.'
            : 'No se pudo obtener acceso al canal de voz.',
      );
    } catch (error) {
      await leaveRoom();
      if (error is LiveKitServiceException) rethrow;
      debugPrint('LiveKit connection rejected: $error');
      final message = error.toString().toLowerCase();
      if (message.contains('permission') || message.contains('notallowed')) {
        throw const LiveKitServiceException('Permiso de micrófono denegado.');
      }
      if (message.contains('failed to fetch') ||
          message.contains('clientexception') ||
          message.contains('network')) {
        throw LiveKitServiceException(
          'No se pudo contactar la función de voz: ${error.toString()}',
        );
      }
      if (message.contains('token') || message.contains('unauthorized')) {
        throw LiveKitServiceException(
          'LiveKit rechazó el token: ${error.toString()}',
        );
      }
      throw LiveKitServiceException(
        'No se pudo conectar con LiveKit: ${error.toString()}',
      );
    }
  }

  Future<void> disconnect() async {
    await _room?.disconnect();
  }

  Future<void> leaveRoom() async {
    final room = _room;
    _room = null;
    if (room == null) return;
    await room.disconnect();
    await room.dispose();
  }

  Future<bool> toggleMicrophone() async {
    final participant = _room?.localParticipant;
    if (participant == null) return false;
    final enabled = !participant.isMicrophoneEnabled();
    await participant.setMicrophoneEnabled(enabled);
    return enabled;
  }

  Future<bool> toggleMute() => toggleMicrophone();

  Future<bool> toggleSpeaker() async {
    final enabled = !AudioManager.instance.isSpeakerOutputPreferred;
    await AudioManager.instance.setSpeakerOutputPreferred(enabled);
    return enabled;
  }

  Future<bool> startAudioPlayback() async {
    final room = _room;
    if (room == null) return false;
    await room.startAudio();
    debugPrint('LiveKit playback unlocked: ${room.canPlaybackAudio}');
    return room.canPlaybackAudio;
  }

  Future<void> setRemoteAudioEnabled(bool enabled) async {
    if (enabled) await _room?.startAudio();
    final participants =
        _room?.remoteParticipants.values ?? const <RemoteParticipant>[];
    for (final participant in participants) {
      for (final publication in participant.audioTrackPublications) {
        if (enabled) {
          await publication.enable();
        } else {
          await publication.disable();
        }
      }
    }
  }

  Future<bool> toggleScreenShare() async {
    final participant = _room?.localParticipant;
    if (participant == null) return false;
    final enabled = !participant.isScreenShareEnabled();
    await participant.setScreenShareEnabled(
      enabled,
      captureScreenAudio: true,
      screenShareCaptureOptions: const ScreenShareCaptureOptions(
        params: VideoParametersPresets.screenShareH1080FPS30,
        captureScreenAudio: true,
      ),
    );
    return enabled;
  }

  Future<List<MediaDevice>> audioInputs() => Hardware.instance.audioInputs();
  Future<List<MediaDevice>> audioOutputs() => Hardware.instance.audioOutputs();

  Future<void> selectAudioInput(MediaDevice device) async {
    final room = _room;
    if (room == null) return;
    await room.setAudioInputDevice(device);
  }

  Future<void> selectAudioOutput(MediaDevice device) async {
    final room = _room;
    if (room == null) return;
    await room.setAudioOutputDevice(device);
  }

  Future<void> dispose() => leaveRoom();
}

class LiveKitServiceException implements Exception {
  const LiveKitServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
