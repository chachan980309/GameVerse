import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

Future<Map<String, dynamic>> extractVideoMetadataImpl(Uint8List bytes, String fileName) async {
  Duration duration = Duration.zero;
  Uint8List? thumbnailBytes;
  int width = 1280;
  int height = 720;
  double aspectRatio = 16 / 9;

  try {
    final ext = fileName.split('.').last.toLowerCase();
    final mime = ext == 'webm' ? 'video/webm' : (ext == 'ogg' ? 'video/ogg' : 'video/mp4');
    
    final blob = html.Blob([bytes], mime);
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    
    final video = html.VideoElement()
      ..src = objectUrl
      ..autoplay = false
      ..muted = true;
    
    video.setAttribute('playsinline', 'true');
    video.setAttribute('crossorigin', 'anonymous');
      
    // Esperar a que carguen los metadatos de forma asíncrona (máximo 3 segundos)
    await video.onLoadedMetadata.first.timeout(const Duration(seconds: 3));
    
    duration = Duration(milliseconds: (video.duration * 1000).toInt());
    width = video.videoWidth > 0 ? video.videoWidth : 1280;
    height = video.videoHeight > 0 ? video.videoHeight : 720;
    aspectRatio = width > 0 && height > 0 ? width / height : 16 / 9;
    
    // Buscar el segundo 0.5 o 1.0 para extraer un cuadro real representativo (máximo 3 segundos)
    video.currentTime = 0.5;
    await video.onSeeked.first.timeout(const Duration(seconds: 3));
    
    final canvas = html.CanvasElement(
      width: width,
      height: height,
    );
    final ctx = canvas.context2D;
    ctx.drawImage(video, 0, 0);
    
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final base64Str = dataUrl.split(',').last;
    thumbnailBytes = base64.decode(base64Str);
    
    html.Url.revokeObjectUrl(objectUrl);
  } catch (e) {
    debugPrint("Error extracting Web video metadata/canvas: $e");
  }

  return {
    'duration': _formatDuration(duration),
    'thumbnailBytes': thumbnailBytes,
    'width': width,
    'height': height,
    'aspectRatio': aspectRatio,
  };
}

String _formatDuration(Duration d) {
  if (d == Duration.zero) return "0:00";
  String two(int n) => n.toString().padLeft(2, '0');
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return "$minutes:${two(seconds)}";
}
