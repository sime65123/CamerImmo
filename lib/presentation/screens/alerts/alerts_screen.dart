import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final alertsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId =
      Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  return Supabase.instance.client
      .from('search_alerts')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .map((data) => data
          .map((e) => Map<String, dynamic>.from(e))
          .toList());
});

// ─── AlertsScreen ─────────────────────────────────────────────────────────────

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: alertsAsync.when(
              loading: () => _AlertsSkeleton(),
              error: (e, __) {
                debugPrint('Alerts error: $e');
                return const Center(
                  child: Text('Erreur de chargement',
                      style: TextStyle(
                          fontFamily: 'Poppins')),
                );
              },
              data: (alerts) {
                if (alerts.isEmpty) {
                  return _EmptyAlerts();
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _AlertCard(
                    alert: alerts[index],
                    onToggle: (id, value) =>
                        _toggleAlert(id, value),
                    onDelete: (id) =>
                        _deleteAlert(context, id, ref),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create-alert'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Créer une alerte',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Mes Alertes',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Soyez notifié des nouveaux biens\ncorrespondant à vos critères.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAlert(
      String id, bool value) async {
    try {
      await Supabase.instance.client
          .from('search_alerts')
          .update({'is_active': value})
          .eq('id', id);
    } catch (e) {
      debugPrint('Toggle alert error: $e');
    }
  }

  Future<void> _deleteAlert(BuildContext context,
      String id, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer l\'alerte',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700)),
        content: const Text(
          'Voulez-vous vraiment supprimer cette alerte ?',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Supprimer',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('search_alerts')
            .delete()
            .eq('id', id);
      } catch (e) {
        debugPrint('Delete alert error: $e');
      }
    }
  }
}

// ─── Alert Card ───────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final Function(String, bool) onToggle;
  final Function(String) onDelete;

  const _AlertCard({
    required this.alert,
    required this.onToggle,
    required this.onDelete,
  });

  String _buildCriteriaSummary() {
    final parts = <String>[];
    final types =
        alert['property_types'] as List?;
    if (types != null && types.isNotEmpty) {
      parts.add(types.first.toString());
    }
    final city = alert['city'] as String?;
    if (city != null) parts.add(city);
    final maxBudget =
        alert['max_budget'] as num?;
    if (maxBudget != null) {
      parts.add('< ${_formatPrice(maxBudget)}');
    }
    return parts.join(' · ');
  }

  String _formatPrice(num price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M FCFA';
    }
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}k FCFA';
    }
    return '${price.toInt()} FCFA';
  }

  String _getFrequencyLabel(String? freq) {
    switch (freq) {
      case 'immediate':
        return 'Immédiate';
      case 'quotidien':
        return 'Quotidienne';
      case 'hebdomadaire':
        return 'Hebdomadaire';
      default:
        return 'Immédiate';
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = alert['id'] as String;
    final name =
        alert['name'] as String? ?? 'Alerte';
    final isActive =
        alert['is_active'] as bool? ?? true;
    final matchesCount =
        alert['matches_count'] as int? ?? 0;
    final frequency =
        alert['frequency'] as String?;
    final lastTriggered =
        alert['last_triggered'] as String?;

    String lastLabel = 'Jamais déclenchée';
    if (lastTriggered != null) {
      final diff = DateTime.now().difference(
          DateTime.parse(lastTriggered));
      if (diff.inMinutes < 60) {
        lastLabel = 'Il y a ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        lastLabel = 'Il y a ${diff.inHours}h';
      } else {
        lastLabel = 'Il y a ${diff.inDays}j';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.primaryLight
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icône
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primaryLight
                        : AppColors.surfaceVariant,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 12),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _buildCriteriaSummary(),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Toggle
                Switch(
                  value: isActive,
                  onChanged: (v) => onToggle(id, v),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),

          // Ligne infos bas
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Badge nouveaux biens
                if (matchesCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$matchesCount nouveau${matchesCount > 1 ? 'x' : ''}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),

                if (matchesCount > 0)
                  const SizedBox(width: 8),

                // Fréquence
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 12,
                          color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        _getFrequencyLabel(frequency),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Dernière activité
                Text(
                  lastLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),

                const SizedBox(width: 8),

                // Supprimer
                GestureDetector(
                  onTap: () => onDelete(id),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.error,
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

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyAlerts extends StatelessWidget {
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
              Icons.notifications_none_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune alerte',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez une alerte pour être notifié\ndes nouveaux biens correspondant\nà vos critères.',
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

class _AlertsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}