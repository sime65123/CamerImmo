import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final darkModeProvider = StateProvider<bool>((ref) => false);
final notifPushProvider = StateProvider<bool>((ref) => true);
final notifEmailProvider = StateProvider<bool>((ref) => false);
final selectedLangProvider =
    StateProvider<String>((ref) => 'Français');

// ─── SettingsScreen ───────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(darkModeProvider);
    final notifPush = ref.watch(notifPushProvider);
    final notifEmail = ref.watch(notifEmailProvider);
    final selectedLang = ref.watch(selectedLangProvider);

    final user =
        Supabase.instance.client.auth.currentUser;
    final fullName =
        user?.userMetadata?['full_name'] as String? ??
            'Utilisateur';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: _buildHeader(context, fullName),
          ),

          // Compte vérifié
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 20, 20, 0),
              child: _VerifiedCard(),
            ),
          ),

          // Notifications
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 24, 20, 0),
              child: _SettingsSection(
                label: 'NOTIFICATIONS',
                children: [
                  _ToggleRow(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications Push',
                    value: notifPush,
                    onChanged: (v) => ref
                        .read(notifPushProvider.notifier)
                        .state = v,
                  ),
                  const Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.borderLight),
                  _ToggleRow(
                    icon: Icons.mail_outline,
                    label: 'Notifications Email',
                    value: notifEmail,
                    onChanged: (v) => ref
                        .read(notifEmailProvider.notifier)
                        .state = v,
                  ),
                ],
              ),
            ),
          ),

          // Sécurité
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 20, 20, 0),
              child: _SettingsSection(
                label: 'SÉCURITÉ & CONFIDENTIALITÉ',
                children: [
                  _ArrowRow(
                    icon: Icons.lock_outline,
                    label: 'Changer le mot de passe',
                    onTap: () =>
                        _showChangePasswordDialog(
                            context),
                  ),
                  const Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.borderLight),
                  _ArrowRow(
                    icon: Icons.fingerprint_outlined,
                    label: 'Authentification Biométrique',
                    onTap: () => _showComingSoon(
                        context,
                        'Authentification Biométrique'),
                  ),
                ],
              ),
            ),
          ),

          // Préférences
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 20, 20, 0),
              child: _SettingsSection(
                label: 'PRÉFÉRENCES',
                children: [
                  _LangRow(
                    selectedLang: selectedLang,
                    onTap: () => _showLangPicker(
                        context, ref, selectedLang),
                  ),
                  const Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.borderLight),
                  _ToggleRow(
                    icon: Icons.dark_mode_outlined,
                    label: 'Mode sombre',
                    value: isDarkMode,
                    onChanged: (v) {
                      ref
                          .read(darkModeProvider.notifier)
                          .state = v;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            v
                                ? 'Mode sombre activé'
                                : 'Mode clair activé',
                            style: const TextStyle(
                                fontFamily: 'Poppins'),
                          ),
                          backgroundColor:
                              AppColors.primary,
                          behavior:
                              SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          margin:
                              const EdgeInsets.all(16),
                          duration:
                              const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Aide & Support
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 20, 20, 0),
              child: _SettingsSection(
                label: 'AIDE & SUPPORT',
                children: [
                  _ArrowRow(
                    icon: Icons.help_outline,
                    label: 'FAQ',
                    onTap: () =>
                        _showFAQ(context),
                  ),
                  const Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.borderLight),
                  _ArrowRow(
                    icon: Icons.headset_mic_outlined,
                    label: 'Contactez-nous',
                    onTap: () =>
                        _showContactDialog(context),
                  ),
                ],
              ),
            ),
          ),

          // À propos
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 20, 20, 0),
              child: _SettingsSection(
                label: 'À PROPOS',
                children: [
                  _ArrowRow(
                    icon: Icons.description_outlined,
                    label: 'CGU',
                    onTap: () =>
                        _showLegal(context, 'CGU'),
                  ),
                  const Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.borderLight),
                  _ArrowRow(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Politique de confidentialité',
                    onTap: () => _showLegal(
                        context,
                        'Politique de confidentialité'),
                  ),
                ],
              ),
            ),
          ),

          // Déconnexion
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 24, 20, 0),
              child: _LogoutButton(),
            ),
          ),

          // Version
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 24),
              child: Column(
                children: const [
                  Text('VERSION v2.0.4',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        letterSpacing: 1,
                      )),
                  SizedBox(height: 4),
                  Text(
                      '© 2024 CamerImmo. Tous droits réservés.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      )),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
              child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, String fullName) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Column(
          children: [
            // Barre nav
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.primary),
                ),
                const Text('Paramètres',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    )),
                const Spacer(),
                const Icon(Icons.more_vert,
                    color: AppColors.textSecondary),
              ],
            ),

            const SizedBox(height: 12),

            // Card profil compact
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceVariant,
                        border: Border.all(
                            color: AppColors.primaryLight,
                            width: 2),
                      ),
                      child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.textTertiary,
                          size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(fullName,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )),
                        Text('Membre Premium • Yaoundé',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color:
                                  AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dialogues ───────────────────────────────────────────────────────────────

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          bool isLoading = false;

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Changer le mot de passe',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  style: const TextStyle(
                      fontFamily: 'Poppins'),
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    labelStyle: const TextStyle(
                        fontFamily: 'Poppins'),
                    prefixIcon: const Icon(
                        Icons.lock_outline),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  style: const TextStyle(
                      fontFamily: 'Poppins'),
                  decoration: InputDecoration(
                    labelText: 'Confirmer',
                    labelStyle: const TextStyle(
                        fontFamily: 'Poppins'),
                    prefixIcon:
                        const Icon(Icons.sync_lock),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (newCtrl.text !=
                            confirmCtrl.text) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Les mots de passe ne correspondent pas !',
                                  style: TextStyle(
                                      fontFamily:
                                          'Poppins')),
                              backgroundColor:
                                  AppColors.error,
                            ),
                          );
                          return;
                        }
                        if (newCtrl.text.length < 6) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Minimum 6 caractères',
                                  style: TextStyle(
                                      fontFamily:
                                          'Poppins')),
                              backgroundColor:
                                  AppColors.error,
                            ),
                          );
                          return;
                        }

                        setState(() => isLoading = true);
                        try {
                          await Supabase
                              .instance.client.auth
                              .updateUser(
                            UserAttributes(
                                password: newCtrl.text),
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Mot de passe modifié !',
                                    style: TextStyle(
                                        fontFamily:
                                            'Poppins')),
                                backgroundColor:
                                    AppColors.success,
                                behavior: SnackBarBehavior
                                    .floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            12)),
                                margin: const EdgeInsets
                                    .all(16),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(
                              () => isLoading = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e',
                                    style: const TextStyle(
                                        fontFamily:
                                            'Poppins')),
                                backgroundColor:
                                    AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                    : const Text('Modifier',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLangPicker(BuildContext context, WidgetRef ref,
      String current) {
    final langs = ['Français', 'English'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Choisir une langue',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...langs.map((lang) => ListTile(
                leading: Icon(
                  Icons.language,
                  color: lang == current
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
                title: Text(lang,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: lang == current
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: lang == current
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    )),
                trailing: lang == current
                    ? const Icon(Icons.check,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  ref
                      .read(
                          selectedLangProvider.notifier)
                      .state = lang;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                          'Langue changée : $lang',
                          style: const TextStyle(
                              fontFamily: 'Poppins')),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                      duration:
                          const Duration(seconds: 2),
                    ),
                  );
                },
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showFAQ(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, ctrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('FAQ',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20),
                children: const [
                  _FAQItem(
                    question:
                        'Comment payer mon loyer ?',
                    answer:
                        'Allez dans Accueil → Mon Bail Actif → Payer maintenant. Choisissez MTN MoMo ou Orange Money.',
                  ),
                  _FAQItem(
                    question:
                        'Comment publier un bien ?',
                    answer:
                        'Basculez en contexte Bailleur depuis le switch en haut, puis cliquez sur "+ Publier un bien".',
                  ),
                  _FAQItem(
                    question:
                        'Comment améliorer mon score de confiance ?',
                    answer:
                        'Payez vos loyers à temps. Le score est calculé automatiquement selon votre historique de paiements.',
                  ),
                  _FAQItem(
                    question:
                        'Comment contacter le support ?',
                    answer:
                        'Utilisez l\'option "Contactez-nous" dans les paramètres ou écrivez à support@camerimmo.cm',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Contactez-nous',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ContactRow(
              icon: Icons.mail_outline,
              label: 'Email',
              value: 'support@camerimmo.cm',
            ),
            const SizedBox(height: 12),
            _ContactRow(
              icon: Icons.phone_outlined,
              label: 'Téléphone',
              value: '+237 6XX XXX XXX',
            ),
            const SizedBox(height: 12),
            _ContactRow(
              icon: Icons.access_time,
              label: 'Horaires',
              value: 'Lun-Ven, 8h-18h',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Fermer',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLegal(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, ctrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20),
                children: [
                  Text(
                    'En utilisant CamerImmo, vous acceptez nos conditions d\'utilisation. '
                    'CamerImmo est une plateforme de mise en relation entre locataires et bailleurs '
                    'au Cameroun. Nous nous engageons à protéger vos données personnelles '
                    'conformément à la législation camerounaise en vigueur.\n\n'
                    'Pour toute question, contactez-nous à legal@camerimmo.cm',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(
      BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Bientôt disponible',
            style:
                const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _VerifiedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user,
              color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Column(
            children: [
              Text('COMPTE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 1,
                  )),
              const Text('Vérifié',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _SettingsSection(
      {required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              letterSpacing: 1,
            )),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: AppColors.textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                )),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _ArrowRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ArrowRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: AppColors.textSecondary, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textPrimary,
          )),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textTertiary, size: 20),
      onTap: onTap,
    );
  }
}

class _LangRow extends StatelessWidget {
  final String selectedLang;
  final VoidCallback onTap;

  const _LangRow(
      {required this.selectedLang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.translate_outlined,
                  color: AppColors.textSecondary,
                  size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Langue',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  )),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(selectedLang,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      )),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.textTertiary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(Icons.logout_rounded,
            color: AppColors.error, size: 18),
        label: const Text('Déconnexion',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            )),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: AppColors.error.withOpacity(0.3)),
          backgroundColor: AppColors.errorLight,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700)),
        content: const Text(
            'Êtes-vous sûr de vouloir vous déconnecter ?',
            style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client.auth
                  .signOut();
              if (context.mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Déconnexion',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── FAQ Item ─────────────────────────────────────────────────────────────────

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;
  const _FAQItem(
      {required this.question, required this.answer});

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ExpansionTile(
        title: Text(widget.question,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            )),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textTertiary,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                16, 0, 16, 16),
            child: Text(widget.answer,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                )),
          ),
        ],
      ),
    );
  }
}

// ─── Contact Row ──────────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textTertiary,
                )),
            Text(value,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                )),
          ],
        ),
      ],
    );
  }
}