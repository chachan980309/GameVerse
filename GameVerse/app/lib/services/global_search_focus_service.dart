import 'package:flutter/foundation.dart';

/// Permite enfocar la búsqueda global desde cualquier pantalla.
class GlobalSearchFocusService extends ChangeNotifier {
  GlobalSearchFocusService._();

  static final instance = GlobalSearchFocusService._();

  void requestFocus() => notifyListeners();
}
