import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import 'main_shell.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  final response = await Supabase.instance.client
      .from('profiles')
      .select()
      .eq('id', userId)
      .maybeSingle();
  return response as Map<String, dynamic>?;
});

final activeLeaseProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  final response = await Supabase.instance.client
      .from('leases')
      .select('*, properties(title, neighborhood, city, monthly_rent)')
      .eq('tenant_id', userId)
      .eq('status', 'actif')
      .maybeSingle();
  return response as Map<String, dynamic>?;
});

final recommendedPropertiesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('properties')
      .select('*, property_images(url, is_primary)')
      .eq('status', 'disponible')
      .order('created_at', ascending: false)
      .limit(10);
  return (response as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

final landlordPropertiesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  final response = await Supabase.instance.client
      .from('properties')
      .select('*, property_images(url, is_primary)')
      .eq('owner_id', userId)
      .order('created_at', ascending: false);
  return (response as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

final landlordStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return {};
  try {
    final response = await Supabase.instance.client
        .rpc('get_landlord_stats', params: {'p_landlord_id': userId});
    if (response == null) return {};
    return Map<String, dynamic>.from(response as Map);
  } catch (e) {
    debugPrint('Stats error: $e');
    return {};
  }
});

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final activeContext = ref.watch(activeContextProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => _HomeShimmer(),
        error: (e, __) {
          debugPrint('Profile error: $e');
          return const Center(
            child: Text(
              'Erreur de chargement',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          );
        },
        data: (profile) {
          final isLandlord = activeContext == 'landlord';
          final firstName =
              (profile?['full_name'] as String? ?? 'Utilisateur')
                  .split(' ')
                  .first;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(
                  context: context,
                  firstName: firstName,
                  activeContext: activeContext,
                  profile: profile,
                ),
              ),
              if (isLandlord)
                ..._buildLandlordContent()
              else
                ..._buildTenantContent(),
            ],
          );
        },
      ),
      floatingActionButton:
          ref.watch(activeContextProvider) == 'landlord'
              ? _PublishFAB()
              : null,
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader({
    required BuildContext context,
    required String firstName,
    required String activeContext,
    required Map<String, dynamic>? profile,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: profile?['avatar_url'] != null
                        ? ClipOval(
                            child: Image.network(
                              profile!['avatar_url'] as String,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                  const SizedBox(width: 12),

                  // Texte bonjour
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeContext == 'landlord'
                              ? 'Bonjour, $firstName'
                              : 'Bonjour,',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                        if (activeContext == 'tenant')
                          Text(
                            '$firstName 👋',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        if (activeContext == 'landlord')
                          Text(
                            'Voici l\'état de votre patrimoine immobilier aujourd\'hui.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Notification
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () {},
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Switch contexte
              _ContextSwitch(
                activeContext: activeContext,
                onChanged: (ctx) {
                  ref.read(activeContextProvider.notifier).state = ctx;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Contenu Locataire ────────────────────────────────────────────────────────

  List<Widget> _buildTenantContent() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _ActiveLeaseCard(),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _SearchBar(controller: _searchController),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: _CategoriesRow(),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Biens recommandés',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/search'),
                child: const Text(
                  'Voir tout →',
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
      ),
      SliverToBoxAdapter(
        child: _RecommendedPropertiesRow(),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];
  }

  // ─── Contenu Bailleur ─────────────────────────────────────────────────────────

  List<Widget> _buildLandlordContent() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _LandlordKPIs(),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vos Propriétés',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Tout voir',
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
      ),
      SliverToBoxAdapter(
        child: _LandlordPropertiesList(),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: const Text(
            'Activité Récente',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _RecentActivityList(),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: _PremiumAdviceCard(),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 120)),
    ];
  }
}

// ─── Switch Contexte ──────────────────────────────────────────────────────────

class _ContextSwitch extends StatelessWidget {
  final String activeContext;
  final ValueChanged<String> onChanged;

  const _ContextSwitch({
    required this.activeContext,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _SwitchTab(
            label: 'Mes Recherches',
            isActive: activeContext == 'tenant',
            onTap: () => onChanged('tenant'),
          ),
          _SwitchTab(
            label: 'Mes Biens',
            isActive: activeContext == 'landlord',
            onTap: () => onChanged('landlord'),
          ),
        ],
      ),
    );
  }
}

class _SwitchTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SwitchTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.primary
                        : Colors.white.withOpacity(0.8),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.check,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Card Bail Actif ──────────────────────────────────────────────────────────

class _ActiveLeaseCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaseAsync = ref.watch(activeLeaseProvider);

    return leaseAsync.when(
      loading: () => _LeaseCardSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (lease) {
        if (lease == null) return _NoLeaseCard();

        final property =
            lease['properties'] as Map<String, dynamic>?;
        final rent = lease['monthly_rent'] as num? ?? 0;
        final paymentDay = lease['payment_day'] as int? ?? 5;
        final now = DateTime.now();
        final dueDate =
            DateTime(now.year, now.month, paymentDay);
        final daysLeft = dueDate.difference(now).inDays;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A3A2A), Color(0xFF0F6E56)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Opacity(
                    opacity: 0.15,
                    child: Image.network(
                      'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'BAIL ACTIF',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      property?['title'] as String? ??
                          'Mon logement',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${property?['neighborhood'] ?? ''}, ${property?['city'] ?? ''}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Loyer info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PROCHAIN LOYER',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 9,
                                    color: Colors.white60,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${rent.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'ÉCHÉANCE',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 9,
                                  color: Colors.white60,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                daysLeft >= 0
                                    ? 'dans $daysLeft jours'
                                    : 'En retard',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: daysLeft <= 3
                                      ? AppColors.accent
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => context.go(
                          '/payment/${lease['id']}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Payer maintenant',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoLeaseCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.home_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aucun bail actif',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Trouvez votre logement idéal',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/search'),
            child: const Text(
              'Explorer →',
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
    );
  }
}

// ─── Barre de recherche ───────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.go('/search'),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Recherche rapide...',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => context.go('/filters'),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Catégories ───────────────────────────────────────────────────────────────

class _CategoriesRow extends StatefulWidget {
  @override
  State<_CategoriesRow> createState() => _CategoriesRowState();
}

class _CategoriesRowState extends State<_CategoriesRow> {
  String _selected = 'Appartement';

  final List<String> _categories = [
    'Appartement',
    'Studio',
    'Villa',
    'Meublé',
    'Bureau',
    'Terrain',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'CATÉGORIES',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat == _selected;
              return GestureDetector(
                onTap: () => setState(() => _selected = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Biens recommandés ────────────────────────────────────────────────────────

class _RecommendedPropertiesRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(recommendedPropertiesProvider);

    return propertiesAsync.when(
      loading: () => SizedBox(
        height: 260,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, __) => _PropertyCardSkeleton(),
        ),
      ),
      error: (e, __) {
        debugPrint('Properties error: $e');
        return const SizedBox.shrink();
      },
      data: (properties) {
        if (properties.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'Aucun bien disponible pour le moment',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: properties.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return _PropertyCard(property: properties[index]);
            },
          ),
        );
      },
    );
  }
}

// ─── Property Card ────────────────────────────────────────────────────────────

class _PropertyCard extends StatefulWidget {
  final Map<String, dynamic> property;
  const _PropertyCard({required this.property});

  @override
  State<_PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<_PropertyCard> {
  bool _isFavorite = false;

  String get _imageUrl {
    final images = widget.property['property_images'] as List?;
    if (images != null && images.isNotEmpty) {
      final primary = images.firstWhere(
        (img) =>
            (img as Map)['is_primary'] == true,
        orElse: () => images.first,
      );
      return (primary as Map)['url'] as String? ?? '';
    }
    return '';
  }

  String _formatPrice(num price) {
    return price
        .toInt()
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final rent = p['monthly_rent'] as num? ?? 0;
    final surface = p['surface_m2'] as num? ?? 0;
    final rooms = p['nb_rooms'] as int? ?? 0;

    return GestureDetector(
      onTap: () => context.go('/property/${p['id']}'),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: _imageUrl.isNotEmpty
                      ? Image.network(
                          _imageUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _PropertyImagePlaceholder(),
                        )
                      : _PropertyImagePlaceholder(),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                        SizedBox(width: 3),
                        Text(
                          '95% MATCH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(
                      () => _isFavorite = !_isFavorite,
                    ),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _isFavorite
                            ? AppColors.error
                            : AppColors.textTertiary,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['title'] as String? ?? '',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          '${p['neighborhood'] ?? ''}, ${p['city'] ?? ''}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatPrice(rent)} FCFA/mois',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.straighten,
                        label: '${surface.toInt()}m²',
                      ),
                      const SizedBox(width: 6),
                      _InfoChip(
                        icon: Icons.bed_outlined,
                        label: '$rooms pièces',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      color: AppColors.surfaceVariant,
      child: const Icon(
        Icons.home_rounded,
        color: AppColors.border,
        size: 40,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: AppColors.textTertiary),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ─── KPIs Bailleur ────────────────────────────────────────────────────────────

class _LandlordKPIs extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(landlordStatsProvider);

    return statsAsync.when(
      loading: () => _KPISkeleton(),
      error: (e, __) {
        debugPrint('KPI error: $e');
        return _KPIGrid(
          revenus: 0,
          biens: 0,
          occupation: 0.0,
          messages: 0,
        );
      },
      data: (stats) => _KPIGrid(
        revenus: (stats['monthly_revenue'] as num?)?.toInt() ?? 0,
        biens:
            (stats['total_properties'] as num?)?.toInt() ?? 0,
        occupation:
            (stats['occupancy_rate'] as num?)?.toDouble() ?? 0.0,
        messages:
            (stats['unread_messages'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class _KPIGrid extends StatelessWidget {
  final int revenus;
  final int biens;
  final double occupation;
  final int messages;

  const _KPIGrid({
    required this.revenus,
    required this.biens,
    required this.occupation,
    required this.messages,
  });

  String _formatRevenue(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return '$amount';
  }

  @override
  Widget build(BuildContext context) {
    final kpis = [
      {
        'icon': Icons.account_balance_wallet_outlined,
        'label': 'REVENUS',
        'value': '${_formatRevenue(revenus)} XAF',
        'color': AppColors.success,
      },
      {
        'icon': Icons.home_outlined,
        'label': 'BIENS',
        'value': '$biens',
        'color': AppColors.primary,
      },
      {
        'icon': Icons.donut_large_outlined,
        'label': 'OCCUPATION',
        'value': '${occupation.toStringAsFixed(0)}%',
        'color': AppColors.info,
      },
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'label': 'MESSAGES',
        'value': '$messages',
        'color': AppColors.accent,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        return Container(
          padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                kpi['icon'] as IconData,
                color: kpi['color'] as Color,
                size: 22,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kpi['value'] as String,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    kpi['label'] as String,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Liste biens bailleur ─────────────────────────────────────────────────────

class _LandlordPropertiesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(landlordPropertiesProvider);

    return propertiesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, __) {
        debugPrint('Landlord properties error: $e');
        return const SizedBox.shrink();
      },
      data: (properties) {
        if (properties.isEmpty) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.add_home_outlined,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucun bien publié',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Publiez votre premier bien pour commencer à recevoir des locataires',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: properties.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _LandlordPropertyCard(
              property: properties[index],
            );
          },
        );
      },
    );
  }
}

class _LandlordPropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  const _LandlordPropertyCard({required this.property});

  Color _statusColor(String status) {
    switch (status) {
      case 'disponible':
        return AppColors.success;
      case 'loue':
        return AppColors.info;
      case 'maintenance':
        return AppColors.warning;
      default:
        return AppColors.textTertiary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'disponible':
        return 'AVAILABLE';
      case 'loue':
        return 'RENTED';
      case 'maintenance':
        return 'MAINTENANCE';
      default:
        return status.toUpperCase();
    }
  }

  String get _imageUrl {
    final images = property['property_images'] as List?;
    if (images != null && images.isNotEmpty) {
      final primary = images.firstWhere(
        (img) => (img as Map)['is_primary'] == true,
        orElse: () => images.first,
      );
      return (primary as Map)['url'] as String? ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final status =
        property['status'] as String? ?? 'disponible';
    final rooms = property['nb_rooms'] as int? ?? 0;
    final surface = property['surface_m2'] as num? ?? 0;

    return Container(
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
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: _imageUrl.isNotEmpty
                    ? Image.network(
                        _imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PropertyImagePlaceholder(),
                      )
                    : _PropertyImagePlaceholder(),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property['title'] as String? ?? '',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${property['neighborhood'] ?? ''}, ${property['city'] ?? ''}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.bed_outlined,
                      label: '$rooms Ch.',
                    ),
                    const SizedBox(width: 12),
                    _InfoChip(
                      icon: Icons.straighten,
                      label: '${surface.toInt()}m²',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (status == 'disponible')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            'Modifier',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Voir demandes',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (status == 'loue')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            'Détails Bail',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              context.go('/documents'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Quittance',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (status == 'maintenance')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Suivre Travaux',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: Colors.white,
                        ),
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

// ─── Activité récente ─────────────────────────────────────────────────────────

class _RecentActivityList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userId =
        Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<List<dynamic>>(
      future: Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(5),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Aucune activité récente',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding:
              const EdgeInsets.symmetric(horizontal: 20),
          itemCount: notifications.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1),
          itemBuilder: (context, index) {
            return _ActivityItem(
              notification: Map<String, dynamic>.from(
                notifications[index] as Map,
              ),
            );
          },
        );
      },
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  const _ActivityItem({required this.notification});

  IconData _getIcon(String type) {
    switch (type) {
      case 'payment':
        return Icons.payments_outlined;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'visite':
        return Icons.calendar_today_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'payment':
        return AppColors.success;
      case 'message':
        return AppColors.primary;
      case 'visite':
        return AppColors.accent;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type =
        notification['type'] as String? ?? 'system';
    final title = notification['title'] as String? ?? '';
    final body = notification['body'] as String? ?? '';
    final createdAt =
        notification['created_at'] as String?;

    String timeAgo = '';
    if (createdAt != null) {
      final diff = DateTime.now()
          .difference(DateTime.parse(createdAt));
      if (diff.inMinutes < 60) {
        timeAgo = 'Il y a ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        timeAgo = 'Il y a ${diff.inHours}h';
      } else {
        timeAgo = 'Il y a ${diff.inDays}j';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getColor(type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getIcon(type),
              color: _getColor(type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            timeAgo,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Conseil Premium ──────────────────────────────────────────────────────────

class _PremiumAdviceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB45309), Color(0xFFD97706)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conseil Premium',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'La demande à Bonapriso a augmenté de 12%. C\'est peut-être le moment de réviser vos tarifs.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/analytics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Analyser le marché',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FAB Publier ──────────────────────────────────────────────────────────────

class _PublishFAB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => context.go('/publish-property'),
      backgroundColor: AppColors.primary,
      elevation: 4,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Publier un bien',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Skeletons ────────────────────────────────────────────────────────────────

class _HomeShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(height: 160, color: AppColors.primary),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: List.generate(
                3,
                (_) => Container(
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaseCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _PropertyCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _KPISkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}