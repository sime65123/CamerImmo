import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension SafeNav on BuildContext {
  /// Retour arrière sûr : si l'historique est vide (écran ouvert via `go`),
  /// on retombe sur l'accueil au lieu de rester bloqué.
  void safePop([String fallback = '/home']) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}
