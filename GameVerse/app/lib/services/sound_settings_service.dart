import 'package:shared_preferences/shared_preferences.dart';

class SoundSettingsService {
  static const String _masterMutedKey = 'master_sounds_muted';
  static const String _notificationSoundsKey = 'notification_sounds_enabled';
  static const String _messageSoundsKey = 'message_sounds_enabled';
  static const String _microphoneDeviceIdKey = 'microphone_device_id';
  static const String _outputDeviceIdKey = 'output_device_id';

  static Future<bool> isMasterMuted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_masterMutedKey) ?? false;
  }

  static Future<bool> areNotificationSoundsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationSoundsKey) ?? true;
  }

  static Future<bool> areMessageSoundsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_messageSoundsKey) ?? true;
  }

  static Future<void> setMasterMuted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_masterMutedKey, value);
  }

  static Future<void> setNotificationSoundsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationSoundsKey, value);
  }

  static Future<void> setMessageSoundsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_messageSoundsKey, value);
  }

  // ============================================================
  // MICRÓFONO
  // ============================================================

  static Future<String?> getMicrophoneDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_microphoneDeviceIdKey);
  }

  static Future<void> setMicrophoneDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_microphoneDeviceIdKey, deviceId);
  }

  static Future<void> clearMicrophoneDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_microphoneDeviceIdKey);
  }

  // ============================================================
  // SALIDA DE AUDIO
  // ============================================================

  static Future<String?> getOutputDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_outputDeviceIdKey);
  }

  static Future<void> setOutputDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_outputDeviceIdKey, deviceId);
  }

  static Future<void> clearOutputDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_outputDeviceIdKey);
  }

  // ============================================================
  // SONIDOS
  // ============================================================

  static Future<bool> canPlaySounds() async {
    final muted = await isMasterMuted();
    return !muted;
  }

  static Future<bool> canPlayNotificationSound() async {
    final masterMuted = await isMasterMuted();

    if (masterMuted) {
      return false;
    }

    return await areNotificationSoundsEnabled();
  }

  static Future<bool> canPlayMessageSound() async {
    final masterMuted = await isMasterMuted();

    if (masterMuted) {
      return false;
    }

    return await areMessageSoundsEnabled();
  }
}
