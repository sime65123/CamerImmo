import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../home/home_screen.dart';

// ─── Provider credit score ────────────────────────────────────────────────────

final creditScoreProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId =
      Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  final response = await Supabase.instance.client
      .from('credit_scores')
      .select()
      .eq('user_id', userId)
      .maybeSingle();
  return response as Map<String, dynamic>?;
});

// ─── Provider stats profil ────────────────────────────────────────────────────

final profileStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final userId =
      Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    return {'biens': 0, 'baux': 0, 'avis': 0};
  }
  try {
    final biens = await Supabase.instance.client
        .from('properties')
        .select('id')
        .eq('owner_id', userId);
    final baux = await Supabase.instance.client
        .from('leases')
        .select('id')
        .or('tenant_id.eq.$userId,landlord_id.eq.$userId');
    final avis = await Supabase.instance.client
        .from('reviews')
        .select('id')
        .eq('reviewed_id', userId);
    return {
      'biens': (biens as List).length,
      'baux': (baux as List).length,
      'avis': (avis as List).length,
    };
  } catch (e) {
    return {'biens': 0, 'baux': 0, 'avis': 0};
  }
});

// ─── ProfileScreen ────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final creditAsync = ref.watch(creditScoreProvider);
    final statsAsync = ref.watch(profileStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary),
        ),
        error: (e, __) => const Center(
            child: Text('Erreur de chargement')),
        data: (profile) {
          if (profile == null) {
            return const Center(
                child: Text('Profil introuvable'));
          }

          final fullName =
              profile['full_name'] as String? ??
                  'Utilisateur';
          final email =
              profile['email'] as String? ?? '';
          final phone =
              profile['phone'] as String? ?? '';
          final avatarUrl =
              profile['avatar_url'] as String?;
          final role =
              profile['role'] as String? ?? 'locataire';
          final isVerified =
              profile['is_verified'] as bool? ?? false;
          final cniVerified =
              profile['cni_verified'] as bool? ?? false;

          String roleLabel;
          switch (role) {
            case 'bailleur':
              roleLabel = 'PROPRIÉTAIRE PREMIUM';
              break;
            case 'les_deux':
              roleLabel = 'MEMBRE PREMIUM';
              break;
            default:
              roleLabel = 'LOCATAIRE';
          }

          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildTopBar(context),
              ),

              // Avatar + nom + rôle
              SliverToBoxAdapter(
                child: _buildAvatarSection(
                  context: context,
                  fullName: fullName,
                  avatarUrl: avatarUrl,
                  roleLabel: roleLabel,
                  isVerified: isVerified,
                ),
              ),

              // Stats
              SliverToBoxAdapter(
                child: statsAsync.when(
                  loading: () => _buildStatsSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (stats) => _buildStats(stats),
                ),
              ),

              // Credit Score
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      20, 20, 20, 0),
                  child: creditAsync.when(
                    loading: () => _buildCreditSkeleton(),
                    error: (_, __) =>
                        const SizedBox.shrink(),
                    data: (credit) => _CreditScoreCard(
                      score:
                          credit?['score'] as int? ?? 500,
                      grade:
                          credit?['grade'] as String? ??
                              'C',
                    ),
                  ),
                ),
              ),

              // Informations
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      20, 20, 20, 0),
                  child: _InfoSection(
                    context: context,
                    email: email,
                    phone: phone,
                    cniVerified: cniVerified,
                    profile: profile,
                  ),
                ),
              ),

              // Liens rapides
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      20, 20, 20, 0),
                  child: _QuickLinks(),
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

              const SliverToBoxAdapter(
                  child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: () => context.go('/settings'),
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
              ),
            ),
            const Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showMoreOptions(context),
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppColors.primary),
              title: const Text('Modifier le profil',
                  style: TextStyle(fontFamily: 'Poppins')),
              onTap: () {
                Navigator.pop(context);
                _showEditProfileDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(
                  Icons.share_outlined,
                  color: AppColors.primary),
              title: const Text('Partager mon profil',
                  style: TextStyle(fontFamily: 'Poppins')),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _EditProfileDialog(),
    );
  }

  Widget _buildAvatarSection({
    required BuildContext context,
    required String fullName,
    required String? avatarUrl,
    required String roleLabel,
    required bool isVerified,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Center(
        child: Column(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceVariant,
                    border: Border.all(
                      color: AppColors.primaryLight,
                      width: 3,
                    ),
                  ),
                  child: avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(
                              Icons.person_rounded,
                              size: 44,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 44,
                          color: AppColors.textTertiary,
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () =>
                        _showEditProfileDialog(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Nom
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.verified,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 4),

            Text(
              roleLabel,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
        child: Row(
          children: [
            _StatItem(
                value: '${stats['biens']}',
                label: 'BIENS'),
            _VertDivider(),
            _StatItem(
                value: '${stats['baux']}',
                label: 'BAUX'),
            _VertDivider(),
            _StatItem(
                value: '${stats['avis']}',
                label: 'AVIS'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildCreditSkeleton() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ─── Stat Item ────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.textTertiary,
                letterSpacing: 1,
              )),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 36, color: AppColors.borderLight);
  }
}

// ─── Credit Score Card ────────────────────────────────────────────────────────

class _CreditScoreCard extends StatelessWidget {
  final int score;
  final String grade;
  const _CreditScoreCard(
      {required this.score, required this.grade});

  Color get _color {
    switch (grade) {
      case 'A+':
      case 'A':
        return AppColors.success;
      case 'B':
        return AppColors.primary;
      case 'C':
        return AppColors.info;
      case 'D':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  String get _label {
    switch (grade) {
      case 'A+':
      case 'A':
        return 'EXCELLENT';
      case 'B':
        return 'TRÈS BON';
      case 'C':
        return 'BON';
      case 'D':
        return 'MOYEN';
      default:
        return 'FAIBLE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text('Mon Score de Confiance',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                  Text('Calculé selon vos engagements',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      )),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _color.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(grade,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _color,
                      )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: '$score',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: _color,
                    ),
                  ),
                  TextSpan(
                    text: ' /1000',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ]),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _color,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 1000,
              backgroundColor: AppColors.borderLight,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_color),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: AppColors.primary, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payez à temps pour améliorer votre score !',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Informations ─────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final BuildContext context;
  final String email;
  final String phone;
  final bool cniVerified;
  final Map<String, dynamic> profile;

  const _InfoSection({
    required this.context,
    required this.email,
    required this.phone,
    required this.cniVerified,
    required this.profile,
  });

  @override
  Widget build(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Informations',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            )),
        const SizedBox(height: 12),
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
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.mail_outline,
                label: 'EMAIL',
                value: email,
                onTap: () => _showEditProfileDialog(ctx),
              ),
              const Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.borderLight),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'TÉLÉPHONE',
                value: phone.isEmpty
                    ? 'Non renseigné'
                    : phone,
                onTap: () => _showEditProfileDialog(ctx),
              ),
              const Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.borderLight),
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'CNI',
                value: cniVerified
                    ? 'Vérifiée'
                    : 'Non vérifiée',
                trailing: cniVerified
                    ? const Icon(Icons.verified,
                        color: AppColors.primary, size: 20)
                    : TextButton(
                        onPressed: () =>
                            _showCniDialog(ctx),
                        child: const Text('Vérifier',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) =>
          _EditProfileDialog(profile: profile),
    );
  }

  void _showCniDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Vérifier votre CNI',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700)),
        content: const Text(
          'Pour vérifier votre identité, veuillez soumettre une photo de votre CNI (recto et verso).',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Soumettre',
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.5,
                      )),
                  Text(value,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      )),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Profile Dialog ──────────────────────────────────────────────────────

class _EditProfileDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? profile;
  const _EditProfileDialog({this.profile});

  @override
  ConsumerState<_EditProfileDialog> createState() =>
      _EditProfileDialogState();
}

class _EditProfileDialogState
    extends ConsumerState<_EditProfileDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.profile?['full_name'] as String? ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: widget.profile?['phone'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final userId =
          Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      }).eq('id', userId);

      // Invalider le provider pour recharger
      ref.invalidate(userProfileProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil mis à jour !',
                style: TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save profile error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: const Text('Modifier le profil',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
          )),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: InputDecoration(
              labelText: 'Nom complet',
              labelStyle:
                  const TextStyle(fontFamily: 'Poppins'),
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: InputDecoration(
              labelText: 'Téléphone',
              labelStyle:
                  const TextStyle(fontFamily: 'Poppins'),
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Enregistrer',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  )),
        ),
      ],
    );
  }
}

// ─── Liens Rapides ────────────────────────────────────────────────────────────

class _QuickLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final links = [
      {
        'icon': Icons.favorite_border_rounded,
        'label': 'Mes favoris',
        'onTap': () => _showComingSoon(context, 'Mes favoris'),
      },
      {
        'icon': Icons.star_border_rounded,
        'label': 'Mes avis',
        'onTap': () => _showComingSoon(context, 'Mes avis'),
      },
      {
        'icon': Icons.notifications_none_rounded,
        'label': 'Mes alertes',
        'onTap': () => context.go('/alerts'),
      },
      {
        'icon': Icons.person_add_outlined,
        'label': 'Inviter un ami',
        'onTap': () => _showInviteDialog(context),
      },
      {
        'icon': Icons.settings_outlined,
        'label': 'Paramètres',
        'onTap': () => context.go('/settings'),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Liens rapides',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            )),
        const SizedBox(height: 12),
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
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: links.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 56,
                color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final link = links[index];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: Icon(
                    link['icon'] as IconData,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ),
                title: Text(
                  link['label'] as String,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary,
                    size: 20),
                onTap: link['onTap'] as VoidCallback,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Bientôt disponible',
            style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Inviter un ami',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700)),
        content: const Text(
          'Partagez CamerImmo avec vos amis et famille !\n\nLien : https://camerimmo.cm/invite',
          style: TextStyle(fontFamily: 'Poppins'),
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
            child: const Text('Partager',
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

// ─── Bouton Déconnexion ───────────────────────────────────────────────────────

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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