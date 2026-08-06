import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

Future<Map<String, dynamic>> extractVideoMetadataImpl(Uint8List bytes, String fileName) async {
  Duration duration = Duration.zero;
  Uint8List? thumbnailBytes;
  int width = 1280;
  int height = 720;
  double aspectRatio = 16 / 9;

  try {
    final player = Player();
    final tempFile = File('${Directory.systemTemp.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
    await tempFile.writeAsBytes(bytes);
    
    final completer = Completer<Duration>();
    final subscription = player.stream.duration.listen((d) {
      if (d != Duration.zero && !completer.isCompleted) {
        completer.complete(d);
      }
    });

    await player.open(Media(tempFile.path), play: false);
    
    duration = await completer.future.timeout(
      const Duration(milliseconds: 1500),
      onTimeout: () => Duration.zero,
    );

    // Seek to 0.5s to render a good frame for screenshot
    await player.seek(const Duration(milliseconds: 500));
    // Wait a tiny moment for the video engine to draw the frame
    await Future.delayed(const Duration(milliseconds: 400));
    
    // Take screenshot using media_kit native feature!
    thumbnailBytes = await player.screenshot();
    
    // Extract native dimensions if available
    final nativeWidth = player.state.width;
    final nativeHeight = player.state.height;
    if (nativeWidth != null && nativeHeight != null && nativeWidth > 0 && nativeHeight > 0) {
      width = nativeWidth;
      height = nativeHeight;
      aspectRatio = width / height;
    }

    await subscription.cancel();
    await player.dispose();
    try {
      await tempFile.delete();
    } catch (_) {}
  } catch (e) {
    debugPrint("Error extracting native video metadata/screenshot: $e");
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
