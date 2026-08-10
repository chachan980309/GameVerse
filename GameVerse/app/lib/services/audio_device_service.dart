import 'package:flutter_webrtc/flutter_webrtc.dart';

class AudioDeviceService {
  // =========================================================
  // DISPOSITIVOS DE ENTRADA
  // =========================================================

  static Future<List<MediaDeviceInfo>> getInputDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();

      return devices.where((device) => device.kind == 'audioinput').toList();
    } catch (e) {
      print('Error obteniendo micrófonos: $e');
      return [];
    }
  }

  // =========================================================
  // DISPOSITIVOS DE SALIDA
  // =========================================================

  static Future<List<MediaDeviceInfo>> getOutputDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();

      return devices.where((device) => device.kind == 'audiooutput').toList();
    } catch (e) {
      print('Error obteniendo dispositivos de salida: $e');
      return [];
    }
  }

  // =========================================================
  // SOLICITAR PERMISO DE MICRÓFONO
  // =========================================================

  static Future<MediaStream?> requestMicrophonePermission() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      return stream;
    } catch (e) {
      print('Error solicitando micrófono: $e');
      return null;
    }
  }

  // =========================================================
  // OBTENER MICRÓFONO ESPECÍFICO
  // =========================================================

  static Future<MediaStream?> openMicrophone(String deviceId) async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': {'deviceId': deviceId},
        'video': false,
      });

      return stream;
    } catch (e) {
      print('Error abriendo micrófono: $e');
      return null;
    }
  }

  // =========================================================
  // DETENER STREAM
  // =========================================================

  static Future<void> stopStream(MediaStream? stream) async {
    if (stream == null) return;

    for (final track in stream.getTracks()) {
      await track.stop();
    }

    await stream.dispose();
  }

  // =========================================================
  // SELECCIONAR SALIDA
  // =========================================================

  static Future<bool> selectOutputDevice(String deviceId) async {
    try {
      await Helper.selectAudioOutput(deviceId);
      return true;
    } catch (e) {
      print('Error seleccionando salida de audio: $e');
      return false;
    }
  }
}
