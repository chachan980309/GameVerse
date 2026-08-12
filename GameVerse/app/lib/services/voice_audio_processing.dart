import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Perfiles de captura de voz usados por todo el canal.
///
/// Cada perfil configura el procesador de audio de LiveKit/WebRTC y las
/// restricciones de la pista del micrófono, no solo el estado de la interfaz.
class VoiceAudioProcessing {
  const VoiceAudioProcessing._({
    required this.mode,
    required this.echoCancellation,
    required this.autoGainControl,
  });

  factory VoiceAudioProcessing.fromSettings({
    required String mode,
    required bool echoCancellation,
    required bool autoGainControl,
  }) => VoiceAudioProcessing._(
    mode: switch (mode) {
      'off' || 'standard' || 'ai' => mode,
      _ => 'standard',
    },
    echoCancellation: echoCancellation,
    autoGainControl: autoGainControl,
  );

  final String mode;
  final bool echoCancellation;
  final bool autoGainControl;

  bool get isDisabled => mode == 'off';
  bool get isAdvanced => mode == 'ai';

  AudioCaptureOptions get captureOptions => AudioCaptureOptions(
    echoCancellation: echoCancellation,
    noiseSuppression: !isDisabled,
    autoGainControl: autoGainControl,
    highPassFilter: !isDisabled,
    // En móvil/escritorio, "software" fuerza el APM de WebRTC en vez de
    // dejar que el sistema elija el procesador.
    noiseSuppressionMode: isAdvanced
        ? AudioProcessingMode.software
        : AudioProcessingMode.automatic,
    voiceIsolation: isAdvanced,
    typingNoiseDetection: !isDisabled,
  );

  AudioProcessingOptions get runtimeOptions => AudioProcessingOptions(
    echoCancellation: echoCancellation,
    noiseSuppression: !isDisabled,
    autoGainControl: autoGainControl,
    highPassFilter: !isDisabled,
    noiseSuppressionMode: isAdvanced
        ? AudioProcessingMode.software
        : AudioProcessingMode.automatic,
  );

  /// Restricciones de navegador sobre la pista ya capturada. Los campos
  /// `goog*` dan cobertura a Chromium; los estándares cubren Firefox/Safari.
  Map<String, dynamic> get mediaConstraints => <String, dynamic>{
    'echoCancellation': echoCancellation,
    'noiseSuppression': !isDisabled,
    'autoGainControl': autoGainControl,
    'voiceIsolation': isAdvanced,
    'googEchoCancellation': echoCancellation,
    'googEchoCancellation2': echoCancellation,
    'googNoiseSuppression': !isDisabled,
    'googNoiseSuppression2': isAdvanced,
    'googAutoGainControl': autoGainControl,
    'googHighpassFilter': !isDisabled,
    'googTypingNoiseDetection': !isDisabled,
  };

  /// Aplica el perfil sin recrear ni silenciar la publicación actual.
  Future<void> applyTo(LocalAudioTrack track) async {
    try {
      await track.setAudioProcessingOptions(runtimeOptions);
    } catch (error) {
      // En web el APM nativo no siempre se expone; las restricciones siguen
      // siendo el camino que el navegador admite para la pista activa.
      debugPrint('Audio processing nativo no disponible: $error');
    }

    try {
      await track.mediaStreamTrack.applyConstraints(mediaConstraints);
    } catch (error) {
      debugPrint('El navegador no aceptó alguna restricción de audio: $error');
    }
  }
}
