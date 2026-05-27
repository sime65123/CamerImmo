import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class CreateAlertScreen extends ConsumerStatefulWidget {
  const CreateAlertScreen({super.key});

  @override
  ConsumerState<CreateAlertScreen> createState() =>
      _CreateAlertScreenState();
}

class _CreateAlertScreenState
    extends ConsumerState<CreateAlertScreen> {
  final _nameCtrl = TextEditingController();
  String _selectedCity = 'Yaoundé';
  final List<String> _selectedTypes = [];
  double _maxBudget = 200000;
  int _minRooms = 1;
  String _frequency = 'immediate';
  bool _isSaving = false;

  final List<Map<String, String>> _propertyTypes = [
    {'value': 'appartement', 'label': 'Appartement'},
    {'value': 'studio', 'label': 'Studio'},
    {'value': 'villa', 'label': 'Villa'},
    {'value': 'chambre', 'label': 'Chambre'},
    {'value': 'bureau', 'label': 'Bureau'},
    {'value': 'terrain', 'label': 'Terrain'},
  ];

  final List<Map<String, String>> _frequencies = [
    {'value': 'immediate', 'label': 'Immédiate'},
    {'value': 'quotidien', 'label': 'Quotidienne'},
    {'value': 'hebdomadaire', 'label': 'Hebdomadaire'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _formatBudget(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M FCFA';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k FCFA';
    }
    return '${value.toInt()} FCFA';
  }

  Future<void> _saveAlert() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Donnez un nom à votre alerte',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId =
          Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      await Supabase.instance.client
          .from('search_alerts')
          .insert({
        'user_id': userId,
        'name': _nameCtrl.text.trim(),
        'city': _selectedCity,
        'property_types': _selectedTypes.isEmpty
            ? null
            : _selectedTypes,
        'max_budget': _maxBudget.toInt(),
        'nb_rooms_min': _minRooms,
        'frequency': _frequency,
        'is_active': true,
        'matches_count': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Alerte créée avec succès !',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        context.go('/alerts');
      }
    } catch (e) {
      debugPrint('Save alert error: $e');
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    4, 8, 20, 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Nouvelle alerte',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Formulaire
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Nom
                  _SectionLabel(label: 'Nom de l\'alerte'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ex: Appart Bastos 2 pièces',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.textHint,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Type de bien
                  _SectionLabel(label: 'Type de bien'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _propertyTypes.map((type) {
                      final isSelected = _selectedTypes
                          .contains(type['value']);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTypes
                                  .remove(type['value']);
                            } else {
                              _selectedTypes
                                  .add(type['value']!);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(
                              milliseconds: 200),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            type['label']!,
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

                  // Ville
                  _SectionLabel(label: 'Ville'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCity,
                        isExpanded: true,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.textTertiary),
                        items: AppConstants.cities
                            .map((city) =>
                                DropdownMenuItem(
                                  value: city,
                                  child: Text(city),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() =>
                                _selectedCity = val);
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Budget max
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionLabel(
                          label: 'Budget maximum'),
                      Text(
                        _formatBudget(_maxBudget),
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
                  Slider(
                    value: _maxBudget,
                    min: 20000,
                    max: 2000000,
                    divisions: 198,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border,
                    onChanged: (val) =>
                        setState(() => _maxBudget = val),
                  ),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text('20k FCFA',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color:
                                  AppColors.textTertiary)),
                      Text('2M FCFA',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color:
                                  AppColors.textTertiary)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Nombre de pièces minimum
                  _SectionLabel(
                      label: 'Pièces minimum'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_minRooms > 1) {
                            setState(() => _minRooms--);
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.remove,
                              color:
                                  AppColors.textSecondary),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24),
                        child: Text(
                          '$_minRooms',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _minRooms++),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add,
                              color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Fréquence
                  _SectionLabel(
                      label: 'Fréquence des notifications'),
                  const SizedBox(height: 12),
                  Row(
                    children: _frequencies.map((freq) {
                      final isSelected =
                          _frequency == freq['value'];
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: freq == _frequencies.last
                                ? 0
                                : 8,
                          ),
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _frequency =
                                    freq['value']!),
                            child: AnimatedContainer(
                              duration: const Duration(
                                  milliseconds: 200),
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius:
                                    BorderRadius.circular(
                                        12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  freq['label']!,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors
                                            .textSecondary,
                                  ),
                                  textAlign:
                                      TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Bouton sauvegarder
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          _isSaving ? null : _saveAlert,
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Enregistrer l\'alerte',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}