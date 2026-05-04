import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import 'search_screen.dart';

class FiltersScreen extends StatelessWidget {
  const FiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FiltersBottomSheet();
  }
}

class FiltersBottomSheet extends ConsumerStatefulWidget {
  const FiltersBottomSheet({super.key});

  @override
  ConsumerState<FiltersBottomSheet> createState() =>
      _FiltersBottomSheetState();
}

class _FiltersBottomSheetState
    extends ConsumerState<FiltersBottomSheet> {
  // État local des filtres
  String? _selectedType;
  double _minBudget = 0;
  double _maxBudget = 5000000;
  int _minRooms = 0;
  int _minBathrooms = 0;
  double _minSurface = 0;
  double _maxSurface = 500;

  final List<Map<String, dynamic>> _propertyTypes = [
    {'label': 'Tous', 'value': null},
    {'label': 'Villa', 'value': 'villa'},
    {'label': 'Appartement', 'value': 'appartement'},
    {'label': 'Studio', 'value': 'studio'},
    {'label': 'Terrain', 'value': 'terrain'},
    {'label': 'Bureau', 'value': 'bureau'},
    {'label': 'Chambre', 'value': 'chambre'},
  ];

  @override
  void initState() {
    super.initState();
    // Charger les filtres existants
    final filters = ref.read(searchFiltersProvider);
    _selectedType = filters['type'] as String?;
    _minBudget = filters['min_budget'] as double? ?? 0;
    _maxBudget =
        filters['max_budget'] as double? ?? 5000000;
    _minRooms = filters['min_rooms'] as int? ?? 0;
    _minSurface =
        filters['min_surface'] as double? ?? 0;
    _maxSurface =
        filters['max_surface'] as double? ?? 500;
  }

  void _applyFilters() {
    ref.read(searchFiltersProvider.notifier).state = {
      'type': _selectedType,
      'min_budget': _minBudget,
      'max_budget': _maxBudget,
      'min_rooms': _minRooms,
      'min_surface': _minSurface,
      'max_surface': _maxSurface,
      'city': 'Yaoundé',
    };
    Navigator.pop(context);
  }

  void _resetFilters() {
    setState(() {
      _selectedType = null;
      _minBudget = 0;
      _maxBudget = 5000000;
      _minRooms = 0;
      _minBathrooms = 0;
      _minSurface = 0;
      _maxSurface = 500;
    });
  }

  String _formatBudget(double value) {
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(
                20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Filtrer les biens',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text(
                    'Réinitialiser',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenu scrollable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type de propriété
                  _SectionTitle(title: 'Type de propriété'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _propertyTypes.map((type) {
                      final isSelected =
                          _selectedType == type['value'];
                      return GestureDetector(
                        onTap: () => setState(
                          () => _selectedType =
                              type['value'] as String?,
                        ),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surfaceVariant,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            type['label'] as String,
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
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Budget
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionTitle(
                          title: 'Budget (FCFA)'),
                      Text(
                        '${_formatBudget(_minBudget)} - ${_formatBudget(_maxBudget)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: RangeValues(
                        _minBudget, _maxBudget),
                    min: 0,
                    max: 5000000,
                    divisions: 100,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border,
                    onChanged: (values) => setState(() {
                      _minBudget = values.start;
                      _maxBudget = values.end;
                    }),
                  ),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0 FCFA',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        '5.000.000+ FCFA',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Chambres
                  const _SectionTitle(title: 'Chambres'),
                  const SizedBox(height: 12),
                  _StepperField(
                    value: _minRooms,
                    onDecrement: () {
                      if (_minRooms > 0) {
                        setState(() => _minRooms--);
                      }
                    },
                    onIncrement: () =>
                        setState(() => _minRooms++),
                  ),

                  const SizedBox(height: 24),

                  // Douches
                  const _SectionTitle(title: 'Douches'),
                  const SizedBox(height: 12),
                  _StepperField(
                    value: _minBathrooms,
                    onDecrement: () {
                      if (_minBathrooms > 0) {
                        setState(() => _minBathrooms--);
                      }
                    },
                    onIncrement: () =>
                        setState(() => _minBathrooms++),
                  ),

                  const SizedBox(height: 24),

                  // Superficie
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionTitle(
                          title: 'Superficie (m²)'),
                      Text(
                        '${_minSurface.toInt()} - ${_maxSurface.toInt()}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values:
                        RangeValues(_minSurface, _maxSurface),
                    min: 0,
                    max: 500,
                    divisions: 50,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border,
                    onChanged: (values) => setState(() {
                      _minSurface = values.start;
                      _maxSurface = values.end;
                    }),
                  ),

                  const SizedBox(height: 32),

                  // Bouton Appliquer
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      child: const Text(
                        'Voir les résultats',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _StepperField({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Bouton -
        GestureDetector(
          onTap: onDecrement,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.remove,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),

        // Valeur
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '$value',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        // Bouton +
        GestureDetector(
          onTap: onIncrement,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}