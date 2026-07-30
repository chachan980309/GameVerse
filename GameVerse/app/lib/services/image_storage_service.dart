import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class ImageStorageService {
  static const _avatarKey = "profile_avatar";
  static const _bannerKey = "profile_banner";

  // ==========================
  // Avatar
  // ==========================

  static Future<void> saveAvatar(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_avatarKey, base64Encode(bytes));
  }

  static Future<Uint8List?> loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();

    final value = prefs.getString(_avatarKey);

    if (value == null) return null;

    return base64Decode(value);
  }

  // ==========================
  // Banner
  // ==========================

  static Future<void> saveBanner(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_bannerKey, base64Encode(bytes));
  }

  static Future<Uint8List?> loadBanner() async {
    final prefs = await SharedPreferences.getInstance();

    final value = prefs.getString(_bannerKey);

    if (value == null) return null;

    return base64Decode(value);
  }

  // ==========================
  // Limpiar imágenes
  // ==========================

  static Future<void> clearImages() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_avatarKey);
    await prefs.remove(_bannerKey);
  }
}
