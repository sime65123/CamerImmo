import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final propertyDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, id) async {
  final response = await Supabase.instance.client
      .from('properties')
      .select('''
        *,
        property_images(url, is_primary, sort_order),
        profiles!properties_owner_id_fkey(
          id, full_name, avatar_url, response_rate,
          avg_response_time, is_verified
        )
      ''')
      .eq('id', id)
      .maybeSingle();
  return response as Map<String, dynamic>?;
});

final propertyReviewsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, propertyId) async {
  final response = await Supabase.instance.client
      .from('reviews')
      .select('*, profiles!reviews_reviewer_id_fkey(full_name, avatar_url)')
      .eq('review_type', 'landlord_review')
      .limit(3);
  return (response as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;
  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  ConsumerState<PropertyDetailScreen> createState() =>
      _PropertyDetailScreenState();
}

class _PropertyDetailScreenState
    extends ConsumerState<PropertyDetailScreen> {
  final PageController _imageController = PageController();
  int _currentImageIndex = 0;
  bool _isFavorite = false;
  bool _descriptionExpanded = false;

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
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
    final propertyAsync =
        ref.watch(propertyDetailProvider(widget.propertyId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: propertyAsync.when(
        loading: () => const _PropertyDetailSkeleton(),
        error: (e, __) {
          debugPrint('Property detail error: $e');
          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.primary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            body: const Center(
              child: Text('Bien introuvable'),
            ),
          );
        },
        data: (property) {
          if (property == null) {
            return const Center(
                child: Text('Bien introuvable'));
          }

          final images =
              (property['property_images'] as List? ?? [])
                ..sort((a, b) =>
                    (a['sort_order'] as int? ?? 0)
                        .compareTo(b['sort_order'] as int? ?? 0));

          final imageUrls = images
              .map((img) => (img as Map)['url'] as String? ?? '')
              .where((url) => url.isNotEmpty)
              .toList();

          final owner = property['profiles'] as Map<String, dynamic>?;
          final rent = property['monthly_rent'] as num? ?? 0;
          final deposit = property['deposit_amount'] as num? ?? 0;
          final surface = property['surface_m2'] as num? ?? 0;
          final rooms = property['nb_rooms'] as int? ?? 0;
          final bathrooms = property['nb_bathrooms'] as int? ?? 0;
          final floor = property['floor'] as int? ?? 0;
          final hasParking = property['has_parking'] as bool? ?? false;
          final hasSecurity = property['has_security'] as bool? ?? false;
          final hasGenerator = property['has_generator'] as bool? ?? false;
          final hasWaterTank = property['has_water_tank'] as bool? ?? false;
          final isFurnished = property['is_furnished'] as bool? ?? false;
          final hasGarden = property['has_garden'] as bool? ?? false;
          final description = property['description'] as String? ?? '';
          final status = property['status'] as String? ?? 'disponible';

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ─── Galerie photos ────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildGallery(
                      context: context,
                      imageUrls: imageUrls,
                      status: status,
                    ),
                  ),

                  // ─── Contenu ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      color: AppColors.background,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                20, 20, 20, 0),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // Titre
                                Text(
                                  property['title'] as String? ??
                                      '',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // Localisation
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${property['neighborhood'] ?? ''}, ${property['city'] ?? ''}',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Prix card
                                _PriceCard(
                                  rent: rent,
                                  deposit: deposit,
                                  formatPrice: _formatPrice,
                                ),

                                const SizedBox(height: 16),

                                // Grille infos rapides
                                _QuickInfoGrid(
                                  rooms: rooms,
                                  bathrooms: bathrooms,
                                  surface: surface,
                                  floor: floor,
                                  hasParking: hasParking,
                                  isFurnished: isFurnished,
                                ),

                                const SizedBox(height: 24),

                                // Description
                                _DescriptionSection(
                                  description: description,
                                  expanded: _descriptionExpanded,
                                  onToggle: () => setState(() =>
                                      _descriptionExpanded =
                                          !_descriptionExpanded),
                                ),

                                const SizedBox(height: 24),

                                // Équipements
                                _EquipmentsSection(
                                  hasParking: hasParking,
                                  hasSecurity: hasSecurity,
                                  hasGenerator: hasGenerator,
                                  hasWaterTank: hasWaterTank,
                                  isFurnished: isFurnished,
                                  hasGarden: hasGarden,
                                  hasBathroom: bathrooms > 0,
                                ),

                                const SizedBox(height: 24),

                                // Emplacement
                                _LocationSection(
                                  neighborhood:
                                      property['neighborhood']
                                              as String? ??
                                          '',
                                  city: property['city']
                                          as String? ??
                                      '',
                                ),

                                const SizedBox(height: 24),

                                // Propriétaire
                                if (owner != null)
                                  _OwnerSection(
                                    owner: owner,
                                    propertyId: widget.propertyId,
                                  ),

                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ─── Boutons sticky bas ────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BottomActions(
                  propertyId: widget.propertyId,
                  ownerId: owner?['id'] as String? ?? '',
                  status: status,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGallery({
    required BuildContext context,
    required List<String> imageUrls,
    required String status,
  }) {
    return Stack(
      children: [
        // Photos
        SizedBox(
          height: 300,
          child: imageUrls.isEmpty
              ? Container(
                  color: AppColors.surfaceVariant,
                  child: const Center(
                    child: Icon(
                      Icons.home_rounded,
                      size: 64,
                      color: AppColors.border,
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _imageController,
                  onPageChanged: (index) => setState(
                    () => _currentImageIndex = index,
                  ),
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    return Image.network(
                      imageUrls[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceVariant,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: AppColors.border,
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Gradient overlay bas
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Badge statut + compteur photos
        Positioned(
          bottom: 16,
          left: 16,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: status == 'disponible'
                      ? AppColors.success
                      : AppColors.info,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status == 'disponible'
                      ? 'Disponible'
                      : 'Loué',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (imageUrls.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1}/${imageUrls.length} Photos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Boutons haut (retour, partager, favori)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GalleryButton(
                  icon: Icons.arrow_back,
                  onTap: () => context.pop(),
                ),
                Row(
                  children: [
                    _GalleryButton(
                      icon: Icons.share_outlined,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _GalleryButton(
                      icon: _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isFavorite
                          ? AppColors.error
                          : Colors.white,
                      onTap: () => setState(
                          () => _isFavorite = !_isFavorite),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Indicateur points
        if (imageUrls.length > 1)
          Positioned(
            bottom: 12,
            right: 16,
            child: Row(
              children: List.generate(
                imageUrls.length.clamp(0, 7),
                (index) => Container(
                  width: index == _currentImageIndex ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: index == _currentImageIndex
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Bouton galerie ───────────────────────────────────────────────────────────

class _GalleryButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _GalleryButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// ─── Card Prix ────────────────────────────────────────────────────────────────

class _PriceCard extends StatelessWidget {
  final num rent;
  final num deposit;
  final String Function(num) formatPrice;

  const _PriceCard({
    required this.rent,
    required this.deposit,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatPrice(rent)} FCFA',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '/mois',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (deposit > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Caution : ${formatPrice(deposit)} FCFA',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // Matching score
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Matching score',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    '95%',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.95,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.primary,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Grille infos rapides ─────────────────────────────────────────────────────

class _QuickInfoGrid extends StatelessWidget {
  final int rooms;
  final int bathrooms;
  final num surface;
  final int floor;
  final bool hasParking;
  final bool isFurnished;

  const _QuickInfoGrid({
    required this.rooms,
    required this.bathrooms,
    required this.surface,
    required this.floor,
    required this.hasParking,
    required this.isFurnished,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.bed_outlined, 'label': '$rooms Chambres'},
      {'icon': Icons.shower_outlined, 'label': '$bathrooms Douches'},
      {
        'icon': Icons.straighten,
        'label': '${surface.toInt()} m²'
      },
      if (hasParking)
        {'icon': Icons.local_parking, 'label': 'Parking'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                item['icon'] as IconData,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                item['label'] as String,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Description ──────────────────────────────────────────────────────────────

class _DescriptionSection extends StatelessWidget {
  final String description;
  final bool expanded;
  final VoidCallback onToggle;

  const _DescriptionSection({
    required this.description,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (description.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
          maxLines: expanded ? null : 3,
          overflow:
              expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onToggle,
          child: Text(
            expanded ? 'Voir moins ∧' : 'Voir plus ∨',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Équipements ──────────────────────────────────────────────────────────────

class _EquipmentsSection extends StatelessWidget {
  final bool hasParking;
  final bool hasSecurity;
  final bool hasGenerator;
  final bool hasWaterTank;
  final bool isFurnished;
  final bool hasGarden;
  final bool hasBathroom;

  const _EquipmentsSection({
    required this.hasParking,
    required this.hasSecurity,
    required this.hasGenerator,
    required this.hasWaterTank,
    required this.isFurnished,
    required this.hasGarden,
    required this.hasBathroom,
  });

  @override
  Widget build(BuildContext context) {
    final equipments = [
      {
        'icon': Icons.wifi,
        'label': 'Wi-Fi Fibre',
        'active': true,
      },
      {
        'icon': Icons.ac_unit,
        'label': 'Climatisation',
        'active': true,
      },
      {
        'icon': Icons.security,
        'label': 'Gardiennage',
        'active': hasSecurity,
      },
      {
        'icon': Icons.water_drop_outlined,
        'label': 'Forage',
        'active': hasWaterTank,
      },
      {
        'icon': Icons.bolt,
        'label': 'Groupe Élec.',
        'active': hasGenerator,
      },
      {
        'icon': Icons.local_parking,
        'label': 'Parking',
        'active': hasParking,
      },
      {
        'icon': Icons.chair_outlined,
        'label': 'Meublé',
        'active': isFurnished,
      },
      {
        'icon': Icons.grass,
        'label': 'Jardin',
        'active': hasGarden,
      },
    ].where((e) => e['active'] == true).toList();

    if (equipments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Équipements',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 3.5,
          ),
          itemCount: equipments.length,
          itemBuilder: (context, index) {
            final eq = equipments[index];
            return Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    eq['icon'] as IconData,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  eq['label'] as String,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─── Emplacement ──────────────────────────────────────────────────────────────

class _LocationSection extends StatelessWidget {
  final String neighborhood;
  final String city;

  const _LocationSection({
    required this.neighborhood,
    required this.city,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emplacement',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0E9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Fond carte simulé
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  size: const Size(double.infinity, 160),
                  painter: _MapPlaceholderPainter(),
                ),
              ),
              // Pin central
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 10,
                      color: AppColors.primary,
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              // Label quartier
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$neighborhood, $city',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4E6D5)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    // Routes horizontales
    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.4),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.7),
      roadPaint,
    );
    // Routes verticales
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.3, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, 0),
      Offset(size.width * 0.7, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Section Propriétaire ─────────────────────────────────────────────────────

class _OwnerSection extends StatelessWidget {
  final Map<String, dynamic> owner;
  final String propertyId;

  const _OwnerSection({
    required this.owner,
    required this.propertyId,
  });

  @override
  Widget build(BuildContext context) {
    final name = owner['full_name'] as String? ?? 'Propriétaire';
    final isVerified = owner['is_verified'] as bool? ?? false;
    final responseRate =
        (owner['response_rate'] as num?)?.toInt() ?? 95;
    final avgTime =
        (owner['avg_response_time'] as num?)?.toInt() ?? 120;
    final avatarUrl = owner['avatar_url'] as String?;

    final responseTimeLabel = avgTime < 60
        ? 'en ${avgTime}min'
        : 'en ${(avgTime / 60).toStringAsFixed(0)}h';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Le propriétaire',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceVariant,
                      border: Border.all(
                        color: AppColors.primaryLight,
                        width: 2,
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
                                color: AppColors.textTertiary,
                                size: 28,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: AppColors.textTertiary,
                            size: 28,
                          ),
                  ),
                  if (isVerified)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
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

              const SizedBox(width: 14),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Propriétaire Premium',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Répond $responseTimeLabel · $responseRate% réponses',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Bouton message
              GestureDetector(
                onTap: () => context.go(
                  '/search',
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Boutons actions bas ──────────────────────────────────────────────────────

class _BottomActions extends StatefulWidget {
  final String propertyId;
  final String ownerId;
  final String status;

  const _BottomActions({
    required this.propertyId,
    required this.ownerId,
    required this.status,
  });

  @override
  State<_BottomActions> createState() => _BottomActionsState();
}

class _BottomActionsState extends State<_BottomActions> {
  bool _isLoading = false;
  bool _leaseLoaded = false;
  String? _leaseId;
  String? _leaseStatus;

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadMyLease();
  }

  /// Bail éventuel du locataire connecté pour ce bien (le plus récent
  /// parmi ceux qui ne sont pas refusés/résiliés).
  Future<void> _loadMyLease() async {
    final uid = _currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _leaseLoaded = true);
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('leases')
          .select('id, status')
          .eq('property_id', widget.propertyId)
          .eq('tenant_id', uid)
          .inFilter('status', ['en_attente', 'actif'])
          .order('created_at', ascending: false)
          .limit(1);
      final list = rows as List;
      if (mounted) {
        setState(() {
          if (list.isNotEmpty) {
            _leaseId = list.first['id'] as String?;
            _leaseStatus = list.first['status'] as String?;
          }
          _leaseLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Load my lease error: $e');
      if (mounted) setState(() => _leaseLoaded = true);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                fontFamily: 'Poppins', color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  bool _isOwner() {
    final uid = _currentUserId;
    return uid != null && uid == widget.ownerId;
  }

  /// Retourne l'id de la conversation existante ou en crée une.
  Future<String> _getOrCreateConversation(String uid,
      {int landlordUnread = 0}) async {
    final existing = await Supabase.instance.client
        .from('conversations')
        .select('id')
        .eq('property_id', widget.propertyId)
        .eq('tenant_id', uid)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final created = await Supabase.instance.client
        .from('conversations')
        .insert({
          'property_id': widget.propertyId,
          'tenant_id': uid,
          'landlord_id': widget.ownerId,
          'tenant_unread': 0,
          'landlord_unread': landlordUnread,
        })
        .select()
        .single();
    return (created as Map<String, dynamic>)['id'] as String;
  }

  Future<void> _handleContact() async {
    final uid = _currentUserId;
    if (uid == null) return;
    if (_isOwner()) {
      _snack('Vous ne pouvez pas vous écrire à vous-même',
          AppColors.warning);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final convId = await _getOrCreateConversation(uid);
      if (mounted) context.go('/chat/$convId');
    } catch (e) {
      debugPrint('Contact error: $e');
      _snack('Erreur: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleRent() {
    final uid = _currentUserId;
    if (uid == null) return;
    if (_isOwner()) {
      _snack('Vous ne pouvez pas louer votre propre bien',
          AppColors.warning);
      return;
    }
    _showRentRequestSheet(uid);
  }

  void _showRentRequestSheet(String uid) {
    final messageCtrl = TextEditingController();
    DateTime? moveInDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Demande de location',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Votre demande sera envoyée au propriétaire pour approbation. '
                'Le paiement se fait une fois la demande acceptée.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Date d\'emménagement souhaitée',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate:
                        DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (date != null) {
                    setModalState(() => moveInDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.textTertiary, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        moveInDate == null
                            ? 'Sélectionner une date'
                            : '${moveInDate!.day}/${moveInDate!.month}/${moveInDate!.year}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: moveInDate == null
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Message au propriétaire (optionnel)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: messageCtrl,
                maxLines: 3,
                style:
                    const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      'Présentez-vous et expliquez votre situation...',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _createLeaseRequest(
                      uid: uid,
                      moveInDate: moveInDate ??
                          DateTime.now().add(const Duration(days: 7)),
                      message: messageCtrl.text.trim(),
                    );
                  },
                  child: const Text(
                    'Envoyer la demande',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createLeaseRequest({
    required String uid,
    required DateTime moveInDate,
    required String message,
  }) async {
    setState(() => _isLoading = true);
    try {
      final property = await Supabase.instance.client
          .from('properties')
          .select('monthly_rent, min_lease_months, deposit_amount')
          .eq('id', widget.propertyId)
          .single();

      final rent = (property['monthly_rent'] as num).toInt();
      final minLease = property['min_lease_months'] as int? ?? 12;
      final deposit =
          (property['deposit_amount'] as num?)?.toInt() ?? rent * 2;

      final endDate = DateTime(
          moveInDate.year, moveInDate.month + minLease, moveInDate.day);

      final lease = await Supabase.instance.client
          .from('leases')
          .insert({
            'property_id': widget.propertyId,
            'tenant_id': uid,
            'landlord_id': widget.ownerId,
            'status': 'en_attente',
            'start_date': moveInDate.toIso8601String(),
            'end_date': endDate.toIso8601String(),
            'monthly_rent': rent,
            'payment_day': 5,
            'deposit_amount': deposit,
            'tenant_message': message,
          })
          .select('id, status')
          .single();

      // Message automatique au propriétaire (n'empêche pas la demande si ça échoue)
      try {
        final convId =
            await _getOrCreateConversation(uid, landlordUnread: 1);
        final d = moveInDate;
        final autoMsg =
            '🏠 Demande de location pour un emménagement le ${d.day}/${d.month}/${d.year}.'
            '${message.isNotEmpty ? '\n\n"$message"' : ''}';
        final now = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('messages').insert({
          'conversation_id': convId,
          'sender_id': uid,
          'content': autoMsg,
          'message_type': 'texte',
        });
        await Supabase.instance.client.from('conversations').update({
          'last_message': autoMsg,
          'last_message_at': now,
          'updated_at': now,
        }).eq('id', convId);
      } catch (e) {
        debugPrint('Auto message error: $e');
      }

      if (mounted) {
        setState(() {
          _leaseId = lease['id'] as String?;
          _leaseStatus = lease['status'] as String?;
        });
      }
      _snack('Demande envoyée ! Le propriétaire va vous répondre.',
          AppColors.success);
    } catch (e) {
      debugPrint('Create lease error: $e');
      _snack('Erreur: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildContent() {
    if (_isLoading || !_leaseLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // Bail accepté → le locataire peut payer (même si le bien est "loué")
    if (_leaseStatus == 'actif' && _leaseId != null) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => context.go('/payment/$_leaseId'),
          icon: const Icon(Icons.payments_outlined,
              size: 18, color: Colors.white),
          label: const Text(
            'Payer mon loyer',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      );
    }

    // Demande envoyée, en attente de réponse
    if (_leaseStatus == 'en_attente') {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Demande envoyée — en attente du propriétaire',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _handleContact,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Icon(Icons.chat_bubble_outline, size: 18),
          ),
        ],
      );
    }

    if (widget.status != 'disponible') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Ce bien n\'est plus disponible',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _handleContact,
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text(
              'Contacter',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _handleRent,
            icon: const Icon(Icons.home_outlined,
                size: 16, color: Colors.white),
            label: const Text(
              'Louer ce bien',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: _buildContent(),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _PropertyDetailSkeleton extends StatelessWidget {
  const _PropertyDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 300,
          color: AppColors.surfaceVariant,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 28,
                  width: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 16,
                  width: 150,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}