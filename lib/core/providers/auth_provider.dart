import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Id de l'utilisateur connecté. Change à chaque connexion / déconnexion,
/// ce qui permet aux providers qui le surveillent de se recharger
/// automatiquement quand on change de compte.
final authUserIdProvider = StateProvider<String?>((ref) {
  final auth = Supabase.instance.client.auth;
  final sub = auth.onAuthStateChange.listen((data) {
    final newId = data.session?.user.id;
    if (ref.controller.state != newId) {
      ref.controller.state = newId;
    }
  });
  ref.onDispose(sub.cancel);
  return auth.currentUser?.id;
});

/// Fait réévaluer les redirections du routeur à chaque changement de session
/// (connexion par mot de passe, retour de Google/Apple, déconnexion).
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
