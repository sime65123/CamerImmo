import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Étape 1
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  final _step1Key = GlobalKey<FormState>();

  // Étape 2
  String _selectedRole = 'locataire';

  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int _passwordStrength(String password) {
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#\$%^&*]'))) strength++;
    return strength;
  }

  String _strengthLabel(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'FAIBLE';
      case 2:
        return 'MOYEN';
      case 3:
        return 'BON';
      default:
        return 'FORT';
    }
  }

  Color _strengthColor(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return AppColors.error;
      case 2:
        return AppColors.warning;
      case 3:
        return AppColors.info;
      default:
        return AppColors.success;
    }
  }

  void _goToStep2() {
    if (!_step1Key.currentState!.validate()) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = 1);
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final phone =
          '${AppConstants.phonePrefix}${_phoneController.text.trim()}';
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      final activeContext =
          _selectedRole == 'bailleur' ? 'landlord' : 'tenant';

      debugPrint('=== DÉBUT INSCRIPTION ===');
      debugPrint('Email: ${_emailController.text.trim()}');
      debugPrint('Phone: $phone');
      debugPrint('Role: $_selectedRole');

      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': _selectedRole,
          'active_context': activeContext,
        },
        emailRedirectTo: 'camerimmo://email-confirmed',
      );

      debugPrint('=== RÉPONSE SUPABASE ===');
      debugPrint('User: ${response.user}');
      debugPrint('User ID: ${response.user?.id}');
      debugPrint('Session: ${response.session}');

      if (response.user == null) {
        debugPrint('ERREUR: user est null');
        throw Exception('Échec de la création du compte');
      }

      debugPrint('=== SUCCÈS - Navigation vers OTP ===');

      if (!mounted) return;
      context.go('/otp?phone=${Uri.encodeComponent(phone)}');

    } on AuthException catch (e) {
      debugPrint('=== AUTH EXCEPTION ===');
      debugPrint('Message: ${e.message}');
      debugPrint('Status: ${e.statusCode}');
      if (mounted) _showError(_translateAuthError(e.message));
    } on PostgrestException catch (e) {
      debugPrint('=== POSTGREST EXCEPTION ===');
      debugPrint('Message: ${e.message}');
      debugPrint('Code: ${e.code}');
      debugPrint('Details: ${e.details}');
      if (mounted) _showError('Erreur base de données: ${e.message}');
    } catch (e) {
      debugPrint('=== EXCEPTION GÉNÉRALE ===');
      debugPrint('Type: ${e.runtimeType}');
      debugPrint('Message: $e');
      if (mounted) _showError('Erreur : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _translateAuthError(String message) {
    if (message.contains('already registered')) {
      return 'Cet email est déjà utilisé.';
    }
    if (message.contains('invalid email')) {
      return 'Adresse email invalide.';
    }
    if (message.contains('weak password')) {
      return 'Mot de passe trop faible (minimum 6 caractères).';
    }
    if (message.contains('rate limit')) {
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    }
    if (message.contains('Database error')) {
      return 'Erreur serveur. Réessayez dans quelques instants.';
    }
    return message;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.domain_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CamerImmo',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Étape ${_currentStep + 1} sur 3',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(3, (index) {
              final isActive = index <= _currentStep;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _currentStep == 0
                  ? 'Informations personnelles'
                  : 'Votre profil',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final password = _passwordController.text;
    final strength = _passwordStrength(password);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Créer mon compte',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Rejoignez la première plateforme immobilière du Cameroun.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Prénom + Nom
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'PRÉNOM',
                    controller: _firstNameController,
                    hint: 'Marc',
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    label: 'NOM',
                    controller: _lastNameController,
                    hint: 'Nguemo',
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Email
            _buildField(
              label: 'EMAIL',
              controller: _emailController,
              hint: 'marc.nguemo@exemple.cm',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline,
              validator: (v) {
                if (v!.isEmpty) return 'Email requis';
                if (!v.contains('@')) return 'Email invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Téléphone
            _buildLabelText('TÉLÉPHONE'),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _CameroonFlag(),
                      const SizedBox(width: 8),
                      const Text(
                        '+237',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '6XX XXX XXX',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.textHint,
                        fontSize: 14,
                      ),
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return 'Téléphone requis';
                      if (v.length < 9) return 'Numéro invalide';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mot de passe
            _buildLabelText('MOT DE PASSE'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                ),
              ),
              validator: (v) {
                if (v!.isEmpty) return 'Mot de passe requis';
                if (v.length < 8) return 'Minimum 8 caractères';
                return null;
              },
            ),

            if (password.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  ...List.generate(4, (i) {
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                        height: 3,
                        decoration: BoxDecoration(
                          color: i < strength
                              ? _strengthColor(strength)
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    'FORCE: ${_strengthLabel(strength)}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _strengthColor(strength),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '8+ caractères',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Confirmer mot de passe
            _buildLabelText('CONFIRMER LE MOT DE PASSE'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(
                  Icons.sync_lock,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirm = !_obscureConfirm,
                  ),
                ),
              ),
              validator: (v) {
                if (v!.isEmpty) return 'Confirmation requise';
                if (v != _passwordController.text) {
                  return 'Les mots de passe ne correspondent pas';
                }
                return null;
              },
            ),

            const SizedBox(height: 28),

            // Bouton Continuer
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _goToStep2,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continuer',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Vous avez déjà un compte ? ',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text(
                      'Se connecter',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            ..._buildFeatures(),
            const SizedBox(height: 40),

            Center(
              child: Text(
                '© 2024 CamerImmo. Tous droits réservés.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'Comment allez-vous\nutiliser CamerImmo ?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Personnalisez votre expérience pour trouver ce dont vous avez besoin plus rapidement.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          _RoleCard(
            icon: Icons.home_outlined,
            iconColor: AppColors.primary,
            iconBg: AppColors.primaryLight,
            title: 'Je cherche un logement',
            subtitle: 'Appartements, villas, terrains à louer ou acheter.',
            value: 'locataire',
            selected: _selectedRole == 'locataire',
            onTap: () => setState(() => _selectedRole = 'locataire'),
          ),

          const SizedBox(height: 12),

          _RoleCard(
            icon: Icons.domain_rounded,
            iconColor: Colors.white,
            iconBg: AppColors.primary,
            title: 'Je propose des biens',
            subtitle: 'Propriétaires, agents et promoteurs immobiliers.',
            value: 'bailleur',
            selected: _selectedRole == 'bailleur',
            onTap: () => setState(() => _selectedRole = 'bailleur'),
          ),

          const SizedBox(height: 12),

          _RoleCard(
            icon: Icons.swap_horiz_rounded,
            iconColor: AppColors.accent,
            iconBg: AppColors.accentLight,
            title: 'Les deux à la fois',
            subtitle: 'Un profil complet pour toutes vos activités.',
            value: 'les_deux',
            selected: _selectedRole == 'les_deux',
            onTap: () => setState(() => _selectedRole = 'les_deux'),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.info,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vous pouvez changer ce choix plus tard dans vos paramètres de profil. Votre interface s\'adaptera automatiquement.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.info,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                    );
                    setState(() => _currentStep = 0);
                  },
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text(
                    'Retour',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 15),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withOpacity(0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Continuer',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              '© 2024 CAMERIMMO • L\'IMMOBILIER DE CONFIANCE AU CAMEROUN',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelText(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: AppColors.textHint,
              fontSize: 14,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.textTertiary, size: 20)
                : null,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildLabelText(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  List<Widget> _buildFeatures() {
    final features = [
      (
        Icons.verified_outlined,
        AppColors.primary,
        AppColors.primaryLight,
        'Propriétés Vérifiées',
        'Chaque annonce est scrupuleusement vérifiée par nos experts locaux.',
      ),
      (
        Icons.account_balance_outlined,
        AppColors.accent,
        AppColors.accentLight,
        'Paiements Sécurisés',
        'Transactions transparentes et traçables pour votre tranquillité d\'esprit.',
      ),
      (
        Icons.location_on_outlined,
        AppColors.primary,
        AppColors.primaryLight,
        'Partout au Cameroun',
        'De Douala à Maroua, trouvez le bien qui correspond à vos rêves.',
      ),
    ];

    return features
        .map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: f.$3,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(f.$1, color: f.$2, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.$4,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        f.$5,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}

// ─── Role Card ────────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLighter : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Drapeau Cameroun ─────────────────────────────────────────────────────────

class _CameroonFlag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: 24,
        height: 16,
        child: Row(
          children: [
            Expanded(child: Container(color: const Color(0xFF007A5E))),
            Expanded(child: Container(color: const Color(0xFFCE1126))),
            Expanded(child: Container(color: const Color(0xFFFCD116))),
          ],
        ),
      ),
    );
  }
}