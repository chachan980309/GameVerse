import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProfileController extends ChangeNotifier {
  static final ProfileController instance = ProfileController._internal();

  factory ProfileController() => instance;

  ProfileController._internal();

  Uint8List? avatar;

  String username = "Usuario";

  String status = "En línea";

  String bio = "";

  void setAvatar(Uint8List? value) {
    avatar = value;
    notifyListeners();
  }

  void setUsername(String value) {
    username = value;
    notifyListeners();
  }

  void setStatus(String value) {
    status = value;
    notifyListeners();
  }

  void setBio(String value) {
    bio = value;
    notifyListeners();
  }
}
