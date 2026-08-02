import 'package:flutter/foundation.dart';

/// Navegación única para abrir un perfil público desde cualquier pantalla.
class ProfileNavigationService extends ValueNotifier<String?> {
  ProfileNavigationService._() : super(null);

  static final ProfileNavigationService instance = ProfileNavigationService._();

  void openProfile(String userId) {
    if (userId.isNotEmpty) value = userId;
  }
}
