import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class ProfileController extends ChangeNotifier {
  static final ProfileController instance = ProfileController._internal();

  factory ProfileController() => instance;

  ProfileController._internal() {
    loadProfile();
  }

  final ProfileService _profileService = ProfileService();

  /// ID del usuario logueado
  String? userId;

  String? avatarUrl;
  String? bannerUrl;
  double bannerPosition = 0;

  String username = "Usuario";
  String status = "En línea";
  String bio = "";
  String handle = "";
  String motto = "";
  String location = "";
  String platform = "";
  String role = "";
  String favoriteGame = "";

  Future<void> loadProfile() async {
    final profile = await _profileService.getProfile();

    if (profile == null) return;

    userId = profile["id"];

    avatarUrl = profile["avatar_url"];
    bannerUrl = profile["banner_url"];
    bannerPosition = (profile["banner_position"] as num?)
            ?.toDouble()
            .clamp(-1.0, 1.0)
            .toDouble() ??
        0;

    username = profile["username"] ?? "Usuario";
    status = profile["status"] ?? "En línea";
    bio = profile["bio"] ?? "";
    handle = profile["handle"] ?? "";
    motto = profile["motto"] ?? "";
    location = profile["location"] ?? "";
    platform = profile["platform"] ?? "";
    role = profile["role"] ?? "";
    favoriteGame = profile["favorite_game"] ?? "";

    notifyListeners();
  }

  Future<void> setAvatar(bytes) async {
    avatarUrl = await _profileService.uploadAvatar(bytes);
    notifyListeners();
  }

  Future<void> setBanner(bytes, {required double verticalPosition}) async {
    bannerUrl = await _profileService.uploadBanner(
      bytes,
      verticalPosition: verticalPosition,
    );
    bannerPosition = verticalPosition.clamp(-1.0, 1.0).toDouble();
    notifyListeners();
  }

  Future<void> updateProfile({
    String? username,
    String? status,
    String? bio,
    String? handle,
    String? motto,
    String? location,
    String? platform,
    String? role,
    String? favoriteGame,
  }) async {
    await _profileService.updateProfile(
      username: username,
      status: status,
      bio: bio,
      handle: handle,
      motto: motto,
      location: location,
      platform: platform,
      role: role,
      favoriteGame: favoriteGame,
    );

    if (username != null) this.username = username;
    if (status != null) this.status = status;
    if (bio != null) this.bio = bio;
    if (handle != null) this.handle = handle;
    if (motto != null) this.motto = motto;
    if (location != null) this.location = location;
    if (platform != null) this.platform = platform;
    if (role != null) this.role = role;
    if (favoriteGame != null) this.favoriteGame = favoriteGame;

    notifyListeners();
  }
}
