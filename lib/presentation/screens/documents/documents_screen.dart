import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final selectedYearProvider = StateProvider<int>((ref) {
  return DateTime.now().year;
});

final selectedDocTabProvider = StateProvider<int>((ref) => 0);

final documentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, Map<String, dynamic>>(
        (ref, params) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  final year = params['year'] as int;
  final type = params['type'] as String?;

  var query = Supabase.instance.client
      .from('documents')
      .select()
      .eq('owner_id', userId)
      .gte('created_at', '$year-01-01')
      .lte('created_at', '$year-12-31');

  if (type != null) {
    query = query.eq('document_type', type);
  }

  final response =
      await query.order('created_at', ascending: false);
  return (response as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

// ─── DocumentsScreen ──────────────────────────────────────────────────────────

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedYear = ref.watch(selectedYearProvider);
    final selectedTab = ref.watch(selectedDocTabProvider);

    final tabTypes = [null, 'quittance_loyer', 'bail_numerique', 'etat_des_lieux'];
    final params = {
      'year': selectedYear,
      'type': tabTypes[selectedTab],
    };
    final documentsAsync = ref.watch(documentsProvider(params));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(context, ref, selectedYear),

          // Onglets
          _buildTabs(ref, selectedTab),

          // Liste
          Expanded(
            child: documentsAsync.when(
              loading: () => _DocumentsSkeleton(),
              error: (e, __) {
                debugPrint('Documents error: $e');
                return const Center(
                  child: Text(
                    'Erreur de chargement',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
                );
              },
              data: (documents) {
                if (documents.isEmpty) {
                  return _EmptyDocuments();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      20, 16, 20, 20),
                  itemCount: documents.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == documents.length) {
                      return _CentralizeCard();
                    }
                    return _DocumentCard(
                      document: documents[index],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, WidgetRef ref, int selectedYear) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl =
        user?.userMetadata?['avatar_url'] as String?;

    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'CamerImmo',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
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

              // Titre + filtre année
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mes Documents',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Gérez vos contrats et quittances\nen toute sécurité.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color:
                              Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),

                  // Sélecteur d'année
                  GestureDetector(
                    onTap: () =>
                        _showYearPicker(context, ref, selectedYear),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white
                              .withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$selectedYear',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 16,
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

  Widget _buildTabs(WidgetRef ref, int selectedTab) {
    final tabs = [
      'Quittances',
      'Baux',
      'États des lieux',
    ];

    return Container(
      color: AppColors.primary,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: 20),
            child: Row(
              children: List.generate(tabs.length, (index) {
                final isSelected = selectedTab == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => ref
                        .read(selectedDocTabProvider.notifier)
                        .state = index,
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.white
                                  .withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        tabs[index],
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showYearPicker(
      BuildContext context, WidgetRef ref, int currentYear) {
    final years = List.generate(
        5, (i) => DateTime.now().year - i);
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
          const Text(
            'Sélectionner une année',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...years.map((year) => ListTile(
                title: Text(
                  '$year',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: year == currentYear
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: year == currentYear
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: year == currentYear
                    ? const Icon(Icons.check,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  ref
                      .read(selectedYearProvider.notifier)
                      .state = year;
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Card Document ────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> document;
  const _DocumentCard({required this.document});

  String _getStatusLabel(String? type) {
    switch (type) {
      case 'quittance_loyer':
        return 'PAYÉ';
      case 'bail_numerique':
        return 'ACTIF';
      case 'etat_des_lieux':
        return 'SIGNÉ';
      default:
        return 'ATTENTE';
    }
  }

  Color _getStatusColor(String? type) {
    switch (type) {
      case 'quittance_loyer':
        return AppColors.success;
      case 'bail_numerique':
        return AppColors.primary;
      case 'etat_des_lieux':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.parse(dateStr).toLocal();
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return 'Émis le ${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _openDocument(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri,
            mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Impossible d\'ouvrir le document',
              style: TextStyle(fontFamily: 'Poppins'),
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
    } catch (e) {
      debugPrint('Open doc error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final type =
        document['document_type'] as String?;
    final title =
        document['title'] as String? ?? 'Document';
    final createdAt =
        document['created_at'] as String?;
    final url = document['url'] as String? ?? '';
    final statusLabel = _getStatusLabel(type);
    final statusColor = _getStatusColor(type);

    return Container(
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
      child: Column(
        children: [
          Row(
            children: [
              // Icône PDF
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'PDF',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE53E3E),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Badge statut
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Boutons actions
          Row(
            children: [
              // Bouton Voir
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: url.isNotEmpty
                      ? () => _openDocument(context, url)
                      : null,
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Voir',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Bouton Télécharger
              _ActionIconButton(
                icon: Icons.download_outlined,
                onTap: url.isNotEmpty
                    ? () => _openDocument(context, url)
                    : null,
              ),

              const SizedBox(width: 8),

              // Bouton Partager
              _ActionIconButton(
                icon: Icons.share_outlined,
                onTap: url.isNotEmpty
                    ? () async {
                        try {
                          final uri = Uri.parse(url);
                          await launchUrl(uri);
                        } catch (e) {
                          debugPrint('Share error: $e');
                        }
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: onTap != null
              ? AppColors.textSecondary
              : AppColors.textTertiary,
          size: 18,
        ),
      ),
    );
  }
}

// ─── Card Centraliser ─────────────────────────────────────────────────────────

class _CentralizeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Centralisez tous vos baux',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Saviez-vous que vous pouvez ajouter vos anciens documents immobiliers pour avoir une vue d\'ensemble sur votre patrimoine ?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.white.withOpacity(0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Ajouter un document',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyDocuments extends StatelessWidget {
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
              Icons.folder_open_outlined,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun document',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos quittances et baux\napparaîtront ici après vos paiements.',
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

class _DocumentsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}