import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final selectedCityAnalyticsProvider =
    StateProvider<String>((ref) => 'Yaoundé');

final marketAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, city) async {
  try {
    final response = await Supabase.instance.client
        .rpc('get_market_analytics',
            params: {'p_city': city, 'p_days': 30});
    if (response == null) return {};
    return Map<String, dynamic>.from(response as Map);
  } catch (e) {
    debugPrint('Market analytics error: $e');
    return {};
  }
});

final priceAnalyticsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, city) async {
  final response = await Supabase.instance.client
      .from('price_analytics')
      .select()
      .eq('city', city)
      .order('avg_price_m2', ascending: false)
      .limit(8);
  return (response as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

final landlordPersonalStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final userId =
      Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return {};
  try {
    final response = await Supabase.instance.client
        .rpc('get_landlord_stats',
            params: {'p_landlord_id': userId});
    if (response == null) return {};
    return Map<String, dynamic>.from(response as Map);
  } catch (e) {
    return {};
  }
});

// ─── AnalyticsScreen ──────────────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = ref.watch(selectedCityAnalyticsProvider);
    final marketAsync =
        ref.watch(marketAnalyticsProvider(selectedCity));
    final priceAsync =
        ref.watch(priceAnalyticsProvider(selectedCity));
    final personalAsync =
        ref.watch(landlordPersonalStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(context, ref, selectedCity),

          // Contenu
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPIs marché
                  marketAsync.when(
                    loading: () => _KPISkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (market) =>
                        _MarketKPIs(market: market),
                  ),

                  const SizedBox(height: 24),

                  // Graphique évolution prix
                  _SectionTitle(
                    title: 'Évolution des Prix',
                    subtitle: '12 derniers mois',
                  ),
                  const SizedBox(height: 12),
                  _PriceEvolutionChart(city: selectedCity),

                  const SizedBox(height: 24),

                  // Prix par quartier
                  _SectionTitle(
                    title: 'Prix par Quartier',
                    subtitle: 'Prix moyen au m² (FCFA)',
                  ),
                  const SizedBox(height: 12),
                  priceAsync.when(
                    loading: () => _ChartSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (prices) =>
                        _NeighborhoodChart(prices: prices),
                  ),

                  const SizedBox(height: 24),

                  // Répartition par type
                  _SectionTitle(
                    title: 'Répartition par Type',
                    subtitle: 'Biens disponibles',
                  ),
                  const SizedBox(height: 12),
                  marketAsync.when(
                    loading: () => _ChartSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (market) =>
                        _TypeDistributionChart(market: market),
                  ),

                  const SizedBox(height: 24),

                  // Stats personnelles bailleur
                  _SectionTitle(
                    title: 'Mes Performances',
                    subtitle: 'Statistiques personnelles',
                  ),
                  const SizedBox(height: 12),
                  personalAsync.when(
                    loading: () => _KPISkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (stats) =>
                        _PersonalStats(stats: stats),
                  ),

                  const SizedBox(height: 24),

                  // Indice de tension locative
                  _SectionTitle(
                    title: 'Indice de Tension Locative',
                    subtitle:
                        'Demande vs offre par quartier',
                  ),
                  const SizedBox(height: 12),
                  priceAsync.when(
                    loading: () => _ListSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (prices) =>
                        _TensionIndex(prices: prices),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, WidgetRef ref, String selectedCity) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Analyse du marché',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Sélecteur ville
                  GestureDetector(
                    onTap: () => _showCityPicker(
                        context, ref, selectedCity),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
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
                            Icons.location_city,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            selectedCity,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
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

              const SizedBox(height: 8),

              Text(
                'Données immobilières en temps réel pour $selectedCity',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCityPicker(
      BuildContext context, WidgetRef ref, String current) {
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
            'Choisir une ville',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...AppConstants.cities.take(6).map(
                (city) => ListTile(
                  leading: Icon(
                    Icons.location_on_outlined,
                    color: city == current
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                  title: Text(
                    city,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: city == current
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: city == current
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: city == current
                      ? const Icon(Icons.check,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(selectedCityAnalyticsProvider
                            .notifier)
                        .state = city;
                    Navigator.pop(context);
                  },
                ),
              ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── KPIs Marché ──────────────────────────────────────────────────────────────

class _MarketKPIs extends StatelessWidget {
  final Map<String, dynamic> market;
  const _MarketKPIs({required this.market});

  String _formatNumber(dynamic value) {
    if (value == null) return '—';
    final amount = (value is num) ? value.toDouble() : 0.0;
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final kpis = [
      {
        'icon': Icons.trending_up_rounded,
        'label': 'Prix moyen/m²',
        'value': '${_formatNumber(market['avg_rent'])} FCFA',
        'change': '+12.4%',
        'positive': true,
        'color': AppColors.primary,
      },
      {
        'icon': Icons.home_outlined,
        'label': 'Biens disponibles',
        'value': _formatNumber(market['available_properties']),
        'change': '+8.2%',
        'positive': true,
        'color': AppColors.success,
      },
      {
        'icon': Icons.timer_outlined,
        'label': 'Délai moyen',
        'value': '18 jours',
        'change': '-3j',
        'positive': true,
        'color': AppColors.info,
      },
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kpis.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final kpi = kpis[index];
          return Container(
            width: 160,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      kpi['icon'] as IconData,
                      color: kpi['color'] as Color,
                      size: 20,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (kpi['positive'] as bool)
                            ? AppColors.successLight
                            : AppColors.errorLight,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        kpi['change'] as String,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: (kpi['positive'] as bool)
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  kpi['value'] as String,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  kpi['label'] as String,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Graphique évolution prix ─────────────────────────────────────────────────

class _PriceEvolutionChart extends StatelessWidget {
  final String city;
  const _PriceEvolutionChart({required this.city});

  @override
  Widget build(BuildContext context) {
    // Données simulées pour le graphique
    final spots = [
      FlSpot(0, 85000),
      FlSpot(1, 88000),
      FlSpot(2, 87000),
      FlSpot(3, 92000),
      FlSpot(4, 95000),
      FlSpot(5, 91000),
      FlSpot(6, 98000),
      FlSpot(7, 102000),
      FlSpot(8, 99000),
      FlSpot(9, 105000),
      FlSpot(10, 110000),
      FlSpot(11, 115000),
    ];

    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
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
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.borderLight,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index % 2 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    months[index % 12],
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  );
                },
                reservedSize: 24,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  return Text(
                    '${(value / 1000).toStringAsFixed(0)}k',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      color: AppColors.textTertiary,
                    ),
                  );
                },
                reservedSize: 32,
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withOpacity(0.08),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${(s.y / 1000).toStringAsFixed(0)}k FCFA',
                        const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Graphique quartiers ──────────────────────────────────────────────────────

class _NeighborhoodChart extends StatelessWidget {
  final List<Map<String, dynamic>> prices;
  const _NeighborhoodChart({required this.prices});

  @override
  Widget build(BuildContext context) {
    if (prices.isEmpty) {
      return const _ChartSkeleton();
    }

    final maxPrice = prices
        .map((p) => (p['avg_price_m2'] as num? ?? 0).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

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
        children: prices.take(6).map((price) {
          final neighborhood =
              price['neighborhood'] as String? ?? '';
          final avgPrice =
              (price['avg_price_m2'] as num? ?? 0).toDouble();
          final ratio = maxPrice > 0 ? avgPrice / maxPrice : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      neighborhood,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${avgPrice.toInt()} FCFA/m²',
                      style: const TextStyle(
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
                    value: ratio,
                    backgroundColor: AppColors.borderLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.lerp(
                            AppColors.primaryLight,
                            AppColors.primaryDark,
                            ratio,
                          ) ??
                          AppColors.primary,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Graphique répartition types ──────────────────────────────────────────────

class _TypeDistributionChart extends StatelessWidget {
  final Map<String, dynamic> market;
  const _TypeDistributionChart({required this.market});

  @override
  Widget build(BuildContext context) {
    final byType =
        market['by_type'] as Map<String, dynamic>? ?? {};

    final types = {
      'appartement': {'label': 'Appartement', 'color': AppColors.primary},
      'studio': {'label': 'Studio', 'color': AppColors.accent},
      'villa': {'label': 'Villa', 'color': AppColors.success},
      'chambre': {'label': 'Chambre', 'color': AppColors.info},
    };

    // Données avec valeurs par défaut si vides
    final sections = types.entries.map((entry) {
      final data = byType[entry.key] as Map? ?? {};
      final count = (data['count'] as num? ?? 0).toDouble();
      return {
        'label': (entry.value['label'] as String),
        'color': (entry.value['color'] as Color),
        'count': count > 0 ? count : 1.0,
      };
    }).toList();

    final total = sections.fold<double>(
        0, (sum, s) => sum + (s['count'] as double));

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
      child: Row(
        children: [
          // Donut chart
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: sections.map((s) {
                  final pct =
                      total > 0 ? (s['count'] as double) / total : 0.0;
                  return PieChartSectionData(
                    color: s['color'] as Color,
                    value: s['count'] as double,
                    title: '${(pct * 100).toStringAsFixed(0)}%',
                    radius: 30,
                    titleStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 20),

          // Légende
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections.map((s) {
                final pct = total > 0
                    ? ((s['count'] as double) / total * 100)
                        .toStringAsFixed(0)
                    : '0';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: s['color'] as Color,
                          borderRadius:
                              BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s['label'] as String,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats personnelles ───────────────────────────────────────────────────────

class _PersonalStats extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _PersonalStats({required this.stats});

  String _formatRevenue(dynamic amount) {
  if (amount == null) return '0';
  final value = (amount is num) ? amount.toDouble() : 0.0;
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)}k';
  }
  return value.toInt().toString();
}

  @override
  Widget build(BuildContext context) {
    final occupancy =
        (stats['occupancy_rate'] as num?)?.toDouble() ?? 0;

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
        children: [
          // Revenus
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Revenus ce mois',
                  value:
                      '${_formatRevenue(stats['monthly_revenue'])} FCFA',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatItem(
                  icon: Icons.home_outlined,
                  label: 'Biens actifs',
                  value:
                      '${stats['total_properties'] ?? 0}',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Taux d'occupation
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Taux d\'occupation',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${occupancy.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: occupancy / 100,
                  backgroundColor: AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    occupancy >= 80
                        ? AppColors.success
                        : occupancy >= 50
                            ? AppColors.warning
                            : AppColors.error,
                  ),
                  minHeight: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.pending_actions_outlined,
                  label: 'Visites en attente',
                  value:
                      '${stats['pending_visits'] ?? 0}',
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatItem(
                  icon: Icons.build_outlined,
                  label: 'Maintenances',
                  value:
                      '${stats['maintenance_open'] ?? 0}',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
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

// ─── Indice de tension ────────────────────────────────────────────────────────

class _TensionIndex extends StatelessWidget {
  final List<Map<String, dynamic>> prices;
  const _TensionIndex({required this.prices});

  @override
  Widget build(BuildContext context) {
    if (prices.isEmpty) return const SizedBox.shrink();

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
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: prices.take(5).length,
        separatorBuilder: (_, __) =>
            const Divider(height: 16),
        itemBuilder: (context, index) {
          final price = prices[index];
          final neighborhood =
              price['neighborhood'] as String? ?? '';
          final sampleSize =
              (price['sample_size'] as num? ?? 0).toInt();

          // Simuler tension selon taille échantillon
          String tensionLabel;
          Color tensionColor;
          if (sampleSize > 40) {
            tensionLabel = 'Très tendu';
            tensionColor = AppColors.error;
          } else if (sampleSize > 25) {
            tensionLabel = 'Tendu';
            tensionColor = AppColors.warning;
          } else {
            tensionLabel = 'Détendu';
            tensionColor = AppColors.success;
          }

          return Row(
            children: [
              Expanded(
                child: Text(
                  neighborhood,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: tensionColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tensionLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tensionColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ─── Skeletons ────────────────────────────────────────────────────────────────

class _KPISkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: 160,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}