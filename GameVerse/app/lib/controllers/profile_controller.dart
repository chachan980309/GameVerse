import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class ProfileController extends ChangeNotifier {
  static final ProfileController instance = ProfileController._internal();

  factory ProfileController() => instance;

  ProfileController._internal() {
    loadProfile();
  }

  final ProfileService _profileService = ProfileService();

  String? avatarUrl;

  String username = "Usuario";
  String status = "En línea";
  String bio = "";

  Future<void> loadProfile() async {
    final profile = await _profileService.getProfile();

    if (profile == null) return;

    avatarUrl = profile["avatar_url"];
    username = profile["username"] ?? "Usuario";
    status = profile["status"] ?? "En línea";
    bio = profile["bio"] ?? "";

    notifyListeners();
  }

  Future<void> setAvatar(bytes) async {
    avatarUrl = await _profileService.uploadAvatar(bytes);
    notifyListeners();
  }

  Future<void> updateProfile({
    String? username,
    String? status,
    String? bio,
  }) async {
    await _profileService.updateProfile(
      username: username,
      status: status,
      bio: bio,
    );

    if (username != null) this.username = username;
    if (status != null) this.status = status;
    if (bio != null) this.bio = bio;

    notifyListeners();
  }
}
