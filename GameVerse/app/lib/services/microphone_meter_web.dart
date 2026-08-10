import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class MicrophoneMeter {
  web.AudioContext? _audioContext;
  web.MediaStreamAudioSourceNode? _source;
  web.AnalyserNode? _analyser;

  Timer? _timer;

  bool get isRunning => _timer != null;

  Future<void> start(
    dynamic flutterStream,
    void Function(double level) onLevel,
  ) async {
    await stop();

    try {
      // ============================================================
      // OBTENER MEDIASTREAM DEL NAVEGADOR
      // ============================================================

      final dynamic jsStream = flutterStream.jsStream;

      final web.MediaStream mediaStream = jsStream as web.MediaStream;

      // ============================================================
      // CREAR AUDIO CONTEXT
      // ============================================================

      _audioContext = web.AudioContext();

      // ============================================================
      // CREAR ANALIZADOR
      // ============================================================

      _analyser = _audioContext!.createAnalyser();

      _analyser!.fftSize = 256;

      // ============================================================
      // CONECTAR MICRÓFONO AL ANALIZADOR
      // ============================================================

      _source = _audioContext!.createMediaStreamSource(mediaStream);

      _source!.connect(_analyser!);

      // ============================================================
      // CREAR BUFFER JAVASCRIPT
      // ============================================================

      final jsData = Uint8List(_analyser!.fftSize).toJS;

      // ============================================================
      // ACTIVAR AUDIO CONTEXT
      // ============================================================

      if (_audioContext!.state == 'suspended') {
        await _audioContext!.resume().toDart;
      }

      // ============================================================
      // MEDIR EL MICRÓFONO
      // ============================================================

      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (_analyser == null) {
          return;
        }

        try {
          // Obtener los datos actuales del micrófono.
          _analyser!.getByteTimeDomainData(jsData);

          // Convertir JSUint8Array -> Uint8List
          final Uint8List data = jsData.toDart;

          if (data.isEmpty) {
            onLevel(0);
            return;
          }

          // ========================================================
          // CALCULAR RMS
          // ========================================================

          double sum = 0;

          for (final value in data) {
            final double normalized = (value - 128) / 128.0;

            sum += normalized * normalized;
          }

          final double rms = math.sqrt(sum / data.length);

          // ========================================================
          // NORMALIZAR NIVEL
          // ========================================================

          double level = rms * 5.0;

          if (level > 1.0) {
            level = 1.0;
          }

          if (level < 0.0) {
            level = 0.0;
          }

          onLevel(level);
        } catch (_) {
          onLevel(0);
        }
      });
    } catch (e) {
      await stop();
      rethrow;
    }
  }

  // ================================================================
  // DETENER MEDIDOR
  // ================================================================

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;

    // Desconectar fuente
    try {
      _source?.disconnect();
    } catch (_) {}

    _source = null;
    _analyser = null;

    // Cerrar AudioContext
    if (_audioContext != null) {
      try {
        await _audioContext!.close().toDart;
      } catch (_) {}
    }

    _audioContext = null;
  }
}
