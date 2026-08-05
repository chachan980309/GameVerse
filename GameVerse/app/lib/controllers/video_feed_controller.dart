import 'package:flutter/material.dart';

class VideoFeedController extends ChangeNotifier {
  String? activeVideoId;

  // activar un video y pausar el anterior
  void setActiveVideo(String videoId) {
    if (activeVideoId == videoId) {
      return;
    }

    activeVideoId = videoId;

    notifyListeners();
  }

  // saber si este video es el que debe reproducirse
  bool isActive(String videoId) {
    return activeVideoId == videoId;
  }

  // detener todo
  void stopAll() {
    activeVideoId = null;

    notifyListeners();
  }

  @override
  void dispose() {
    activeVideoId = null;

    super.dispose();
  }
}
