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

    final requestBody = {
      'room': roomName,
      'userId': user.id,
      'username': username?.isNotEmpty == true
          ? username
          : (user.email ?? 'Usuario'),
    };

    try {
      const fullUrl = "https://[Supabase_Project]/functions/v1/livekit-token";
      print("[CALL] --- INICIANDO SOLICITUD DE TOKEN ---");
      print("[CALL] URL llamada: $fullUrl");
      print("[CALL] Body enviado: $requestBody");

      final response = await _supabase.functions.invoke(
        'livekit-token',
        body: requestBody,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      
      print("[CALL] --- RESPUESTA RECIBIDA ---");
      print("[CALL] Código HTTP de respuesta: ${response.status}");
      print("[CALL] Body completo de respuesta: ${response.data}");

      final data = Map<String, dynamic>.from(response.data as Map);
      if (data.containsKey('error')) {
        print("[CALL] ERROR EN EDGE FUNCTION RESPONDIDO: ${data['error']}");
        throw LiveKitServiceException(data['error'].toString());
      }
      final token = data['token']?.toString() ?? '';
      final url = data['url']?.toString() ?? '';
      final tokenParts = token.split('.').length;
      final urlScheme = Uri.tryParse(url)?.scheme;
      
      print("[CALL] Token recibido con longitud: ${token.length}");
      print("[CALL] Room asociada al token: $roomName");
      print("[CALL] Credenciales procesadas: url=$url, tokenParts=$tokenParts");

      if (tokenParts != 3 || urlScheme != 'wss') {
        throw const LiveKitServiceException(
          'La respuesta de LiveKit no es válida.',
        );
      }

      print("[CALL] Inicializando Room de LiveKit...");
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
      
      print("[CALL] Ejecutando prepareConnection...");
      await room.prepareConnection(url, token);
      print("[CALL] prepareConnection OK");

      print("[CALL] Ejecutando room.connect...");
      await room.connect(url, token);
      print("[CALL] room.connect OK. ConnectionState: ${room.connectionState.name}");

      print("[CALL] Iniciando audio...");
      await room.startAudio();
      print("[CALL] startAudio OK");

      print("[CALL] Publicando micrófono...");
      final publication = await room.localParticipant?.setMicrophoneEnabled(
        true,
      );
      print("[CALL] setMicrophoneEnabled OK. micPublished=${publication != null}");
      print("[CALL] ¡Conexión WebRTC / LiveKit completada con éxito!");
      print("Sala unida en LiveKit: $roomName");
      print("Identity enviada a LiveKit: ${user.id}");
      return room;
    } on FunctionException catch (error, stack) {
      print("[CALL] EXCEPCIÓN DE EDGE FUNCTION CAPTURADA:");
      print("Status: ${error.status}");
      print("Details: ${error.details}");
      print("Error string: ${error.toString()}");
      print(stack.toString());
      
      await leaveRoom();
      
      String errMsg = 'Error de la Edge Function (${error.status}): ';
      if (error.details is Map) {
        final detailsMap = error.details as Map;
        errMsg += detailsMap['error']?.toString() ?? detailsMap['message']?.toString() ?? error.toString();
      } else if (error.details != null) {
        errMsg += error.details.toString();
      } else {
        errMsg += error.toString();
      }
      
      throw LiveKitServiceException(errMsg);
    } catch (error, stack) {
      print("[CALL] EXCEPCIÓN GENERAL EN WEBRTC / LIVEKIT: $error");
      print(stack.toString());
      await leaveRoom();
      if (error is LiveKitServiceException) rethrow;
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
