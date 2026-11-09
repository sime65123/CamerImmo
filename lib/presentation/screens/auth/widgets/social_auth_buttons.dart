import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';

/// Boutons « Continuer avec Google / Apple ».
///
/// La connexion se termine hors de l'app (navigateur). Au retour, Supabase
/// ouvre la session et le routeur redirige vers /home tout seul.
class SocialAuthButtons extends StatefulWidget {
  final void Function(String message) onError;
  const SocialAuthButtons({super.key, required this.onError});

  @override
  State<SocialAuthButtons> createState() => _SocialAuthButtonsState();
}

class _SocialAuthButtonsState extends State<SocialAuthButtons> {
  OAuthProvider? _loading;

  /// Apple n'est proposé que sur iOS, macOS et le web.
  bool get _showApple =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> _signIn(OAuthProvider provider) async {
    if (_loading != null) return;
    setState(() => _loading = provider);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        // Web : retour sur l'URL courante. Mobile : lien profond de l'app.
        redirectTo: kIsWeb ? null : 'camerimmo://login-callback',
      );
    } on AuthException catch (e) {
      debugPrint('OAuth ${provider.name} error: ${e.message}');
      widget.onError(_friendly(provider, e.message));
    } catch (e) {
      debugPrint('OAuth ${provider.name} error: $e');
      widget.onError(
          'Connexion ${_label(provider)} impossible pour le moment.');
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  String _label(OAuthProvider p) =>
      p == OAuthProvider.apple ? 'Apple' : 'Google';

  String _friendly(OAuthProvider p, String raw) {
    if (raw.contains('provider is not enabled') ||
        raw.contains('Unsupported provider')) {
      return 'La connexion ${_label(p)} n\'est pas encore activée.';
    }
    return 'Connexion ${_label(p)} échouée. Réessayez.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SocialButton(
          label: 'Continuer avec Google',
          loading: _loading == OAuthProvider.google,
          enabled: _loading == null,
          leading: const _GoogleLogo(),
          onPressed: () => _signIn(OAuthProvider.google),
        ),
        if (_showApple) ...[
          const SizedBox(height: 12),
          _SocialButton(
            label: 'Continuer avec Apple',
            loading: _loading == OAuthProvider.apple,
            enabled: _loading == null,
            leading: const Icon(Icons.apple, size: 24, color: Colors.black),
            onPressed: () => _signIn(OAuthProvider.apple),
          ),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool enabled;
  final Widget leading;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.label,
    required this.loading,
    required this.enabled,
    required this.leading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Bleu
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.5,
      1.6,
      false,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    // Rouge
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      1.1,
      1.2,
      false,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    // Jaune
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.3,
      0.8,
      false,
      Paint()
        ..color = const Color(0xFFFBBC05)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    // Vert
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.1,
      0.7,
      false,
      Paint()
        ..color = const Color(0xFF34A853)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}