import 'package:shared_preferences/shared_preferences.dart';

class SoundSettingsService {
  static const String _masterMutedKey = 'master_sounds_muted';
  static const String _notificationSoundsKey = 'notification_sounds_enabled';
  static const String _messageSoundsKey = 'message_sounds_enabled';

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

  /// Determina si un sonido puede reproducirse.
  ///
  /// Si el usuario activó "silenciar todos los sonidos",
  /// ningún sonido debe reproducirse.
  static Future<bool> canPlaySounds() async {
    final muted = await isMasterMuted();

    return !muted;
  }

  /// Determina si se puede reproducir un sonido de notificación.
  static Future<bool> canPlayNotificationSound() async {
    final masterMuted = await isMasterMuted();

    if (masterMuted) {
      return false;
    }

    return await areNotificationSoundsEnabled();
  }

  /// Determina si se puede reproducir un sonido de mensaje.
  static Future<bool> canPlayMessageSound() async {
    final masterMuted = await isMasterMuted();

    if (masterMuted) {
      return false;
    }

    return await areMessageSoundsEnabled();
  }
}
