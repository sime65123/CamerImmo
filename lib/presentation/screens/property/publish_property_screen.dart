import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class PublishPropertyScreen extends ConsumerStatefulWidget {
  const PublishPropertyScreen({super.key});

  @override
  ConsumerState<PublishPropertyScreen> createState() =>
      _PublishPropertyScreenState();
}

class _PublishPropertyScreenState
    extends ConsumerState<PublishPropertyScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // Étape 1
  String _selectedType = 'appartement';
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _availableFrom;

  // Étape 2
  String _selectedCity = 'Yaoundé';
  final _neighborhoodCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Étape 3
  double _surface = 50;
  int _rooms = 2;
  int _bathrooms = 1;
  int _floor = 0;
  bool _hasParking = false;
  bool _hasSecurity = false;
  bool _hasGenerator = false;
  bool _hasWaterTank = false;
  bool _isFurnished = false;
  bool _hasGarden = false;

  // Étape 4
  final List<XFile> _selectedImages = [];
  final _rentCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  int _minLease = 12;
  Map<String, dynamic>? _aiSuggestion;

  final List<Map<String, dynamic>> _propertyTypes = [
    {'value': 'appartement', 'label': 'Appartement', 'icon': Icons.apartment},
    {'value': 'villa', 'label': 'Villa', 'icon': Icons.home},
    {'value': 'studio', 'label': 'Studio', 'icon': Icons.bed},
    {'value': 'chambre', 'label': 'Chambre', 'icon': Icons.bedroom_parent},
    {'value': 'bureau', 'label': 'Bureau', 'icon': Icons.business},
    {'value': 'terrain', 'label': 'Terrain', 'icon': Icons.landscape},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _addressCtrl.dispose();
    _rentCtrl.dispose();
    _depositCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);

      // Charger suggestion IA à l'étape 4
      if (_currentStep == 3) {
        _loadAiSuggestion();
      }
    } else {
      _publishProperty();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _loadAiSuggestion() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'suggest_property_price',
        params: {
          'p_city': _selectedCity,
          'p_neighborhood': _neighborhoodCtrl.text.trim(),
          'p_type': _selectedType,
          'p_surface': _surface,
        },
      );
      if (response != null && mounted) {
        setState(() => _aiSuggestion =
            Map<String, dynamic>.from(response as Map));
      }
    } catch (e) {
      debugPrint('AI suggestion error: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      debugPrint('Pick images error: $e');
    }
  }

  Future<void> _publishProperty() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError('Donnez un titre à votre bien');
      return;
    }
    if (_rentCtrl.text.trim().isEmpty) {
      _showError('Entrez le loyer mensuel');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId =
          Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      final rent = int.tryParse(
              _rentCtrl.text.replaceAll(' ', '')) ??
          0;
      final deposit = int.tryParse(
              _depositCtrl.text.replaceAll(' ', '')) ??
          0;

      // Insérer le bien
      final response = await Supabase.instance.client
          .from('properties')
          .insert({
        'owner_id': userId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'property_type': _selectedType,
        'status': 'disponible',
        'city': _selectedCity,
        'neighborhood': _neighborhoodCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'surface_m2': _surface,
        'nb_rooms': _rooms,
        'nb_bathrooms': _bathrooms,
        'floor': _floor,
        'has_parking': _hasParking,
        'has_security': _hasSecurity,
        'has_generator': _hasGenerator,
        'has_water_tank': _hasWaterTank,
        'is_furnished': _isFurnished,
        'has_garden': _hasGarden,
        'monthly_rent': rent,
        'deposit_amount': deposit,
        'min_lease_months': _minLease,
        'available_from': _availableFrom?.toIso8601String(),
        'ai_suggested_price':
            _aiSuggestion?['suggested_price'],
      })
          .select()
          .single();

      final propertyId =
          (response as Map<String, dynamic>)['id']
              as String;

      // Upload images
      for (int i = 0; i < _selectedImages.length; i++) {
        try {
          final bytes =
              await _selectedImages[i].readAsBytes();
          final fileName =
              'prop_${propertyId}_$i.jpg';
          final path =
              '$propertyId/$fileName';

          await Supabase.instance.client.storage
              .from(AppConstants.propertyImagesBucket)
              .uploadBinary(path, bytes);

          final url = Supabase.instance.client.storage
              .from(AppConstants.propertyImagesBucket)
              .getPublicUrl(path);

          await Supabase.instance.client
              .from('property_images')
              .insert({
            'property_id': propertyId,
            'storage_path': path,
            'url': url,
            'is_primary': i == 0,
            'sort_order': i,
          });
        } catch (e) {
          debugPrint('Upload image $i error: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Bien publié avec succès !',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      debugPrint('Publish error: $e');
      _showError('Erreur lors de la publication : $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final stepLabels = [
      'Infos générales',
      'Localisation',
      'Caractéristiques',
      'Photos & Prix',
    ];

    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              20, 12, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.close,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Publier un bien',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentStep + 1}/4',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Barre de progression
              Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                          right: i < 3 ? 4 : 0),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _currentStep
                            ? Colors.white
                            : Colors.white
                                .withOpacity(0.3),
                        borderRadius:
                            BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  stepLabels[_currentStep],
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle(title: 'Type de bien'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.3,
            ),
            itemCount: _propertyTypes.length,
            itemBuilder: (context, index) {
              final type = _propertyTypes[index];
              final isSelected =
                  _selectedType == type['value'];
              return GestureDetector(
                onTap: () => setState(
                    () => _selectedType =
                        type['value'] as String),
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight
                        : AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        type['icon'] as IconData,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type['label'] as String,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          const _StepTitle(title: 'Titre de l\'annonce'),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ex: Appartement meublé Bastos',
              hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textHint,
                  fontSize: 14),
            ),
          ),

          const SizedBox(height: 20),

          const _StepTitle(title: 'Description'),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Décrivez votre bien...',
              hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textHint,
                  fontSize: 14),
            ),
          ),

          const SizedBox(height: 20),

          const _StepTitle(
              title: 'Disponible à partir du'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now()
                    .add(const Duration(days: 365)),
                builder: (context, child) =>
                    Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (date != null) {
                setState(() => _availableFrom = date);
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
                  const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.textTertiary,
                      size: 18),
                  const SizedBox(width: 10),
                  Text(
                    _availableFrom == null
                        ? 'Sélectionner une date'
                        : '${_availableFrom!.day}/${_availableFrom!.month}/${_availableFrom!.year}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: _availableFrom == null
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle(title: 'Ville'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
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
                    .map((city) => DropdownMenuItem(
                          value: city,
                          child: Text(city),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCity = val);
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          const _StepTitle(title: 'Quartier'),
          const SizedBox(height: 8),
          TextField(
            controller: _neighborhoodCtrl,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ex: Bastos, Biyem-Assi...',
              hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textHint,
                  fontSize: 14),
              prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.textTertiary),
            ),
          ),

          const SizedBox(height: 20),

          const _StepTitle(
              title: 'Adresse précise (optionnel)'),
          const SizedBox(height: 8),
          TextField(
            controller: _addressCtrl,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Rue, n° de porte...',
              hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textHint,
                  fontSize: 14),
            ),
          ),

          const SizedBox(height: 16),

          // Note confidentialité
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.info, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'L\'adresse exacte ne sera visible qu\'après la signature du bail.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Surface
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const _StepTitle(title: 'Surface (m²)'),
              Text('${_surface.toInt()} m²',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _surface,
            min: 10,
            max: 500,
            divisions: 49,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.border,
            onChanged: (val) =>
                setState(() => _surface = val),
          ),

          const SizedBox(height: 20),

          // Pièces
          const _StepTitle(title: 'Chambres'),
          const SizedBox(height: 12),
          _StepperWidget(
            value: _rooms,
            min: 1,
            onDecrement: () => setState(
                () => _rooms = (_rooms - 1).clamp(1, 20)),
            onIncrement: () =>
                setState(() => _rooms++),
          ),

          const SizedBox(height: 20),

          // Salles de bain
          const _StepTitle(title: 'Salles de bain'),
          const SizedBox(height: 12),
          _StepperWidget(
            value: _bathrooms,
            min: 1,
            onDecrement: () => setState(
                () => _bathrooms =
                    (_bathrooms - 1).clamp(1, 10)),
            onIncrement: () =>
                setState(() => _bathrooms++),
          ),

          const SizedBox(height: 20),

          // Étage
          const _StepTitle(title: 'Étage'),
          const SizedBox(height: 12),
          _StepperWidget(
            value: _floor,
            min: 0,
            label: _floor == 0 ? 'RDC' : 'Étage $_floor',
            onDecrement: () => setState(
                () => _floor =
                    (_floor - 1).clamp(0, 30)),
            onIncrement: () =>
                setState(() => _floor++),
          ),

          const SizedBox(height: 24),

          // Équipements
          const _StepTitle(title: 'Équipements'),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 3.5,
            children: [
              _EquipmentToggle(
                icon: Icons.local_parking,
                label: 'Parking',
                value: _hasParking,
                onChanged: (v) =>
                    setState(() => _hasParking = v),
              ),
              _EquipmentToggle(
                icon: Icons.security,
                label: 'Gardiennage',
                value: _hasSecurity,
                onChanged: (v) =>
                    setState(() => _hasSecurity = v),
              ),
              _EquipmentToggle(
                icon: Icons.bolt,
                label: 'Groupe électrogène',
                value: _hasGenerator,
                onChanged: (v) =>
                    setState(() => _hasGenerator = v),
              ),
              _EquipmentToggle(
                icon: Icons.water_drop_outlined,
                label: 'Château d\'eau',
                value: _hasWaterTank,
                onChanged: (v) =>
                    setState(() => _hasWaterTank = v),
              ),
              _EquipmentToggle(
                icon: Icons.chair_outlined,
                label: 'Meublé',
                value: _isFurnished,
                onChanged: (v) =>
                    setState(() => _isFurnished = v),
              ),
              _EquipmentToggle(
                icon: Icons.grass,
                label: 'Jardin',
                value: _hasGarden,
                onChanged: (v) =>
                    setState(() => _hasGarden = v),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photos
          const _StepTitle(title: 'Photos'),
          const SizedBox(height: 4),
          Text(
            'Ajoutez au moins 3 photos de qualité',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Grille photos
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _selectedImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _selectedImages.length) {
                return GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.border,
                          style:
                              BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate,
                            color: AppColors.primary,
                            size: 28),
                        const SizedBox(height: 4),
                        Text('Ajouter',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: AppColors.primary,
                            )),
                      ],
                    ),
                  ),
                );
              }
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(12),
                    child: Image.network(
                      _selectedImages[index].path,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          Container(
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.image,
                            color: AppColors.border),
                      ),
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: const Text('Principal',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.w600)),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() =>
                          _selectedImages
                              .removeAt(index)),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white,
                            size: 12),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Prix
          const _StepTitle(title: 'Loyer mensuel (FCFA)'),
          const SizedBox(height: 8),
          TextField(
            controller: _rentCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '150 000',
              hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textHint),
              suffixText: 'FCFA',
              suffixStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textTertiary),
            ),
          ),

          // Suggestion IA
          if (_aiSuggestion != null &&
              _aiSuggestion!['suggested_price'] != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                _rentCtrl.text =
                    '${_aiSuggestion!['suggested_price']}';
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryLight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: AppColors.primary,
                        size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prix suggéré par CamerImmo IA',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            '${_aiSuggestion!['min_price']} – ${_aiSuggestion!['max_price']} FCFA',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text('Appliquer',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          const _StepTitle(title: 'Caution (FCFA)'),
          const SizedBox(height: 8),
          TextField(
            controller: _depositCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 14),
            decoration: InputDecoration(
              hintText: '300 000',
              hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textHint,
                  fontSize: 14),
              suffixText: 'FCFA',
              suffixStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textTertiary),
            ),
          ),

          const SizedBox(height: 20),

          // Durée minimale
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const _StepTitle(
                  title: 'Durée minimale du bail'),
              Text('$_minLease mois',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _minLease.toDouble(),
            min: 1,
            max: 24,
            divisions: 23,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.border,
            onChanged: (val) =>
                setState(() => _minLease = val.toInt()),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLastStep = _currentStep == 3;

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
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back,
                    size: 16),
                label: const Text('Retour',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      AppColors.textSecondary,
                  side: const BorderSide(
                      color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                ),
              ),
            ),
          if (_currentStep > 0)
            const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _nextStep,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5))
                    : Text(
                        isLastStep
                            ? 'Publier l\'annonce'
                            : 'Continuer',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

// ─── Widgets helpers ──────────────────────────────────────────────────────────

class _StepTitle extends StatelessWidget {
  final String title;
  const _StepTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ));
  }
}

class _StepperWidget extends StatelessWidget {
  final int value;
  final int min;
  final String? label;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _StepperWidget({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.min = 0,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onDecrement,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: value <= min
                  ? AppColors.surfaceVariant
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.remove,
                color: value <= min
                    ? AppColors.textTertiary
                    : AppColors.textSecondary),
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            label ?? '$value',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        GestureDetector(
          onTap: onIncrement,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add,
                color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _EquipmentToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _EquipmentToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? AppColors.primaryLight
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                value ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: value
                    ? AppColors.primary
                    : AppColors.textTertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: value
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}