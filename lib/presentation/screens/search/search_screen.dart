import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import 'filters_screen.dart'; // ← AJOUTER CETTE LIGNE

// ─── Providers ────────────────────────────────────────────────────────────────

// Filtres actifs
final searchFiltersProvider =
    StateProvider<Map<String, dynamic>>((ref) => {
      'type': null,
      'min_budget': 0.0,
      'max_budget': 5000000.0,
      'min_rooms': 0,
      'min_surface': 0.0,
      'max_surface': 500.0,
      'city': 'Yaoundé',
    });

// Résultats de recherche
final searchResultsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, Map<String, dynamic>>(
        (ref, filters) async {
  var query = Supabase.instance.client
      .from('properties')
      .select('*, property_images(url, is_primary)')
      .eq('status', 'disponible');

  if (filters['type'] != null) {
    query = query.eq('property_type', filters['type']);
  }
  if ((filters['max_budget'] as double) < 5000000) {
    query = query.lte('monthly_rent', filters['max_budget']);
  }
  if ((filters['min_budget'] as double) > 0) {
    query = query.gte('monthly_rent', filters['min_budget']);
  }
  if ((filters['min_rooms'] as int) > 0) {
    query = query.gte('nb_rooms', filters['min_rooms']);
  }
  if (filters['city'] != null &&
      (filters['city'] as String).isNotEmpty) {
    query = query.eq('city', filters['city']);
  }

  // ✅ order() et limit() appliqués en dehors de la variable query
  final response = await query
      .order('created_at', ascending: false)
      .limit(20);

  return (response as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

// ─── SearchScreen ─────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  bool _isListView = true;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FiltersBottomSheet(),
    );
  }

  int get _activeFiltersCount {
    final filters = ref.read(searchFiltersProvider);
    int count = 0;
    if (filters['type'] != null) count++;
    if ((filters['min_budget'] as double) > 0) count++;
    if ((filters['max_budget'] as double) < 5000000) count++;
    if ((filters['min_rooms'] as int) > 0) count++;
    if ((filters['min_surface'] as double) > 0) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);
    final resultsAsync =
        ref.watch(searchResultsProvider(filters));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header vert
          _buildHeader(),

          // Corps
          Expanded(
            child: resultsAsync.when(
              loading: () => _SearchSkeleton(),
              error: (e, __) {
                debugPrint('Search error: $e');
                return Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Erreur de chargement',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
              data: (properties) {
                // Filtrage local par texte
                final filtered = _searchQuery.isEmpty
                    ? properties
                    : properties.where((p) {
                        final title = (p['title'] as String? ?? '')
                            .toLowerCase();
                        final neighborhood =
                            (p['neighborhood'] as String? ?? '')
                                .toLowerCase();
                        final query =
                            _searchQuery.toLowerCase();
                        return title.contains(query) ||
                            neighborhood.contains(query);
                      }).toList();

                if (filtered.isEmpty) {
                  return _EmptySearch();
                }

                return Column(
                  children: [
                    // Résultats count + toggle vue
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          20, 16, 20, 0),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filtered.length} bien${filtered.length > 1 ? 's' : ''} trouvé${filtered.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          _ViewToggle(
                            isListView: _isListView,
                            onToggle: (val) => setState(
                              () => _isListView = val,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Liste des biens
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            20, 0, 20, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return _SearchPropertyCard(
                            property: filtered[index],
                            matchScore: 95 - (index * 3),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      // FAB Message
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/conversations'),
        backgroundColor: AppColors.primary,
        mini: true,
        child: const Icon(Icons.chat_bubble_outline,
            color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              // Titre + Logo
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.domain_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'CamerImmo',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // Notification bell
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Barre de recherche
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) =>
                            setState(() => _searchQuery = val),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Bastos, Yaoundé...',
                          hintStyle: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: AppColors.textHint,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.textTertiary,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: AppColors.textTertiary,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(
                                        () => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          filled: false,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Bouton filtres
                  GestureDetector(
                    onTap: _openFilters,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          if (_activeFiltersCount > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$_activeFiltersCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Toggle Vue Liste/Carte ───────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool isListView;
  final ValueChanged<bool> onToggle;

  const _ViewToggle({
    required this.isListView,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _ToggleBtn(
            icon: Icons.view_list_rounded,
            label: 'Liste',
            isActive: isListView,
            onTap: () => onToggle(true),
          ),
          _ToggleBtn(
            icon: Icons.map_outlined,
            label: 'Carte',
            isActive: !isListView,
            onTap: () => onToggle(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:
              isActive ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? AppColors.primary
                  : AppColors.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: isActive
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isActive
                    ? AppColors.primary
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card Bien (Recherche) ────────────────────────────────────────────────────

class _SearchPropertyCard extends StatefulWidget {
  final Map<String, dynamic> property;
  final int matchScore;

  const _SearchPropertyCard({
    required this.property,
    required this.matchScore,
  });

  @override
  State<_SearchPropertyCard> createState() =>
      _SearchPropertyCardState();
}

class _SearchPropertyCardState
    extends State<_SearchPropertyCard> {
  bool _isFavorite = false;

  String get _imageUrl {
    final images =
        widget.property['property_images'] as List?;
    if (images != null && images.isNotEmpty) {
      final primary = images.firstWhere(
        (img) => (img as Map)['is_primary'] == true,
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
    final hasParking = p['has_parking'] as bool? ?? false;
    final isFurnished = p['is_furnished'] as bool? ?? false;

    return GestureDetector(
      onTap: () => context.go('/property/${p['id']}'),
      child: Container(
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
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: _imageUrl.isNotEmpty
                      ? Image.network(
                          _imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _SearchImagePlaceholder(),
                        )
                      : _SearchImagePlaceholder(),
                ),

                // Badge Match Score
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.matchScore}% Matching',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Badges VERIFIED / NEW
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Row(
                    children: [
                      _BadgeChip(
                        label: 'VERIFIED',
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      _BadgeChip(
                        label: 'PREMIUM',
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),

                // Favori
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => setState(
                        () => _isFavorite = !_isFavorite),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(0.1),
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
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Infos
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre + Prix
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['title'] as String? ?? '',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
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
                                  size: 13,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${p['neighborhood'] ?? ''}, ${p['city'] ?? ''}',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_formatPrice(rent)}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            'FCFA / MOIS',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9,
                              color: AppColors.textTertiary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Caractéristiques
                  Row(
                    children: [
                      _FeatureChip(
                        icon: Icons.straighten,
                        label: '${surface.toInt()}m²',
                      ),
                      const SizedBox(width: 12),
                      _FeatureChip(
                        icon: Icons.bed_outlined,
                        label: '$rooms',
                      ),
                      if (hasParking) ...[
                        const SizedBox(width: 12),
                        _FeatureChip(
                          icon: Icons.local_parking,
                          label: 'Parking',
                        ),
                      ],
                      if (isFurnished) ...[
                        const SizedBox(width: 12),
                        _FeatureChip(
                          icon: Icons.chair_outlined,
                          label: 'Meublé',
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Bas : Répond en + Bouton
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Répond en 2h',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => context
                            .go('/property/${p['id']}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 0,
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Voir Détails',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
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

class _SearchImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      color: AppColors.surfaceVariant,
      child: const Icon(
        Icons.home_rounded,
        color: AppColors.border,
        size: 48,
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _BadgeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptySearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun bien trouvé',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos filtres\nou votre zone de recherche',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _SearchSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Container(
        height: 320,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}