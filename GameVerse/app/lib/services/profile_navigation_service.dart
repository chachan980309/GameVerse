import 'package:flutter/foundation.dart';

/// Navegación única para abrir un perfil público desde cualquier pantalla.
class ProfileNavigationService extends ValueNotifier<String?> {
  ProfileNavigationService._() : super(null);

  static final ProfileNavigationService instance = ProfileNavigationService._();

  void openProfile(String userId) {
    if (userId.isEmpty) return;

    // ValueNotifier no emite cambios cuando se le asigna el mismo valor. Eso
    // impedía volver a abrir un perfil desde el feed, comentarios o búsqueda
    // después de regresar a otra pestaña.
    if (value == userId) {
      notifyListeners();
      return;
    }
    value = userId;
  }

  void clear() {
    if (value != null) value = null;
  }
}
