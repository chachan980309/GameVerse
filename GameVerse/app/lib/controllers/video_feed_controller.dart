import 'package:flutter/material.dart';

class VideoFeedController extends ChangeNotifier {
  int? activeVideo;

  // activar un video y pausar el anterior
  void setActiveVideo(int index) {
    if (activeVideo == index) {
      return;
    }

    activeVideo = index;

    notifyListeners();
  }

  // saber si este video es el que debe reproducirse
  bool isActive(int index) {
    return activeVideo == index;
  }

  // detener todo
  void stopAll() {
    activeVideo = null;

    notifyListeners();
  }

  @override
  void dispose() {
    activeVideo = null;

    super.dispose();
  }
}
