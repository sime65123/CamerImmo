import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with TickerProviderStateMixin {
  bool _isResending = false;
  bool _isChecking = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Email du user inscrit
  String get _userEmail {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.email ?? '';
  }

  String get _maskedEmail {
    final email = _userEmail;
    if (email.isEmpty) return 'votre adresse email';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    final masked = name.length > 3
        ? '${name.substring(0, 3)}${'•' * (name.length - 3)}'
        : name;
    return '$masked@$domain';
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      // Tenter de se connecter avec email pour vérifier
      // si l'email a été confirmé
      // On ne peut pas rafraîchir la session car il n'y a pas de session
      // (l'utilisateur n'est pas encore connecté)

      // On vérifie via une tentative de récupération du user
      // depuis Supabase en utilisant l'email stored
      final email = _userEmail;

      if (email.isEmpty) {
        // Pas de user en mémoire → aller vers login
        if (mounted) {
          _showSnackBar(
            'Session expirée. Veuillez vous connecter.',
            isError: false,
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go('/login');
        }
        return;
      }

      // Vérifier si l'email est confirmé via admin client
      // On utilise un appel REST direct à Supabase
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      debugPrint('Profile check: $response');

      if (response != null) {
        // Le profil existe → le trigger a fonctionné
        // → l'email a été confirmé
        if (mounted) {
          _showSnackBar(
            'Email confirmé ! Connectez-vous pour accéder à votre compte.',
            isError: false,
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go('/login');
        }
      } else {
        // Profil pas encore créé → email pas encore confirmé
        if (mounted) {
          _showSnackBar(
            'Email pas encore confirmé. Vérifiez votre boite mail.',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur check: $e');
      // Si erreur RLS → profil existe mais RLS bloque
      // → email probablement confirmé → aller vers login
      if (mounted) {
        _showSnackBar(
          'Vérification effectuée. Connectez-vous à votre compte.',
          isError: false,
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/login');
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      final email = _userEmail;
      if (email.isNotEmpty) {
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: email,
          emailRedirectTo: 'http://localhost:${Uri.base.port}',
        );
        if (mounted) {
          _showSnackBar(
            'Email de confirmation renvoyé !',
            isError: false,
          );
        }
      } else {
        if (mounted) {
          _showSnackBar(
            'Impossible de récupérer l\'email. Recommencez l\'inscription.',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur renvoi: $e');
      if (mounted) {
        _showSnackBar(
          'Impossible de renvoyer l\'email. Réessayez.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Logo
              const Text(
                'CamerImmo',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 32),

              // Indicateur étapes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepIndicator(
                      number: 1, isDone: true, isActive: false),
                  const _StepLine(),
                  _StepIndicator(
                      number: 2, isDone: true, isActive: false),
                  const _StepLine(),
                  _StepIndicator(
                      number: 3, isDone: false, isActive: true),
                  const SizedBox(width: 12),
                  Text(
                    'Étape 3 sur 3',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Illustration animée
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.mark_email_unread_outlined,
                        size: 52,
                        color: AppColors.primary,
                      ),
                      Positioned(
                        top: 18,
                        right: 18,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Titre
              const Text(
                'Vérifiez votre email',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Un lien de confirmation a été envoyé à\n',
                    ),
                    TextSpan(
                      text: _maskedEmail,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Card instructions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _InstructionStep(
                      number: '1',
                      icon: Icons.inbox_outlined,
                      text: 'Ouvrez votre boite mail',
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    _InstructionStep(
                      number: '2',
                      icon: Icons.search_outlined,
                      text:
                          'Cherchez un email de "CamerImmo" ou "noreply@mail.app.supabase.io"',
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    _InstructionStep(
                      number: '3',
                      icon: Icons.touch_app_outlined,
                      text:
                          'Cliquez sur "Confirmer mon adresse email"',
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    _InstructionStep(
                      number: '4',
                      icon: Icons.check_circle_outline,
                      text:
                          'Revenez ici et cliquez "J\'ai confirmé mon email"',
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Note spam
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Si vous ne trouvez pas l\'email, vérifiez vos spams.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Bouton J'ai confirmé
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withOpacity(0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'J\'ai confirmé mon email',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Bouton renvoyer
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _isResending ? null : _resendEmail,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppColors.border,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isResending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.refresh,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Renvoyer l\'email de confirmation',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Changer email
              GestureDetector(
                onTap: () => context.go('/register'),
                child: Text(
                  'Utiliser une autre adresse email',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Support
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Un problème ? ',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    'Contactez le support',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

class _InstructionStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String text;
  final Color color;

  const _InstructionStep({
    required this.number,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int number;
  final bool isDone;
  final bool isActive;

  const _StepIndicator({
    required this.number,
    required this.isDone,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDone || isActive ? AppColors.primary : AppColors.border,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                '$number',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 2,
      color: AppColors.primary,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}