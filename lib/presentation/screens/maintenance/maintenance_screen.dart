import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';

/// Signalements de maintenance d'un logement.
///
/// - Locataire (`leaseId`) : voit ses signalements et peut en créer.
/// - Bailleur (`propertyId`) : voit ceux de son bien et change leur statut.
class MaintenanceScreen extends StatefulWidget {
  final String? leaseId;
  final String? propertyId;
  const MaintenanceScreen({super.key, this.leaseId, this.propertyId});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _uid = Supabase.instance.client.auth.currentUser?.id;

  bool _loading = true;
  String? _error;
  String? _propertyId;
  String? _leaseId;
  String? _landlordId;
  String _propertyTitle = '';
  List<Map<String, dynamic>> _requests = [];

  bool get _isLandlord => _uid != null && _uid == _landlordId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = Supabase.instance.client;
      if (widget.leaseId != null) {
        final lease = await db
            .from('leases')
            .select('id, property_id, landlord_id, properties(title)')
            .eq('id', widget.leaseId!)
            .single();
        _leaseId = lease['id'] as String?;
        _propertyId = lease['property_id'] as String?;
        _landlordId = lease['landlord_id'] as String?;
        _propertyTitle =
            (lease['properties'] as Map?)?['title'] as String? ?? '';
      } else if (widget.propertyId != null) {
        final property = await db
            .from('properties')
            .select('id, owner_id, title')
            .eq('id', widget.propertyId!)
            .single();
        _propertyId = property['id'] as String?;
        _landlordId = property['owner_id'] as String?;
        _propertyTitle = property['title'] as String? ?? '';
      } else {
        throw Exception('Logement non précisé');
      }

      var query = db
          .from('maintenance_requests')
          .select()
          .eq('property_id', _propertyId!);
      if (!_isLandlord && _uid != null) {
        query = query.eq('tenant_id', _uid!);
      }
      final rows = await query.order('created_at', ascending: false);
      _requests = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('Maintenance load error: $e');
      _error = 'Impossible de charger les signalements.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(Map<String, dynamic> r, String status) async {
    try {
      await Supabase.instance.client
          .from('maintenance_requests')
          .update({'status': status}).eq('id', r['id'] as String);
      await _load();
    } catch (e) {
      debugPrint('Maintenance status error: $e');
      if (mounted) _toast('Mise à jour impossible : $e', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white)),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MaintenanceForm(
        propertyId: _propertyId!,
        leaseId: _leaseId,
        landlordId: _landlordId!,
        onCreated: () {
          _toast('Signalement envoyé au propriétaire.');
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: (!_loading && _error == null && !_isLandlord)
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Signaler un problème',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  )),
            )
          : null,
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/home'),
                      icon:
                          const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Maintenance',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              )),
                          if (_propertyTitle.isNotEmpty)
                            Text(_propertyTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(fontFamily: 'Poppins')),
            TextButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.build_circle_outlined,
                  size: 56, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(
                _isLandlord
                    ? 'Aucun signalement pour ce bien.'
                    : 'Aucun signalement. Un souci dans votre logement ? Signalez-le au propriétaire.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(_requests[i]),
      ),
    );
  }

  static const _categoryIcons = {
    'plomberie': Icons.plumbing,
    'electricite': Icons.bolt,
    'serrure': Icons.lock_outline,
    'peinture': Icons.format_paint_outlined,
    'equipements': Icons.kitchen_outlined,
    'autre': Icons.build_outlined,
  };

  Widget _card(Map<String, dynamic> r) {
    final status = (r['status'] as String? ?? '').toLowerCase();
    final resolved = status.contains('resol');
    final inProgress = status.contains('cours');
    final statusLabel =
        resolved ? 'Résolu' : (inProgress ? 'En cours' : 'Ouvert');
    final statusColor = resolved
        ? AppColors.success
        : (inProgress ? AppColors.info : AppColors.warning);

    final priority = (r['priority'] as String? ?? 'normale').toLowerCase();
    final priorityColor = priority == 'critique'
        ? AppColors.error
        : (priority == 'urgente' ? AppColors.warning : AppColors.textTertiary);

    final created = DateTime.tryParse(r['created_at']?.toString() ?? '');
    final date = created == null
        ? ''
        : '${created.toLocal().day}/${created.toLocal().month}/${created.toLocal().year}';
    final photos = (r['photos'] as List?)?.cast<String>() ?? const <String>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _categoryIcons[r['category']] ?? Icons.build_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['title'] as String? ?? 'Signalement',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                    Text(date,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        )),
                  ],
                ),
              ),
              _pill(statusLabel, statusColor),
            ],
          ),
          if ((r['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(r['description'] as String,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                )),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _pill('Priorité : $priority', priorityColor),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(photos[i],
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.broken_image_outlined,
                              color: AppColors.border))),
                ),
              ),
            ),
          ],
          if (_isLandlord && !resolved) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (!inProgress)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setStatus(r, 'en_cours'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: BorderSide(
                            color: AppColors.info.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Prendre en charge',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                  ),
                if (!inProgress) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _setStatus(r, 'resolu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Marquer résolu',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            )),
      );
}

// ─── Formulaire de signalement ────────────────────────────────────────────────

class _MaintenanceForm extends StatefulWidget {
  final String propertyId;
  final String? leaseId;
  final String landlordId;
  final VoidCallback onCreated;
  const _MaintenanceForm({
    required this.propertyId,
    required this.leaseId,
    required this.landlordId,
    required this.onCreated,
  });

  @override
  State<_MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends State<_MaintenanceForm> {
  static const _categories = [
    ('plomberie', 'Plomberie', Icons.plumbing),
    ('electricite', 'Électricité', Icons.bolt),
    ('serrure', 'Serrure', Icons.lock_outline),
    ('peinture', 'Peinture', Icons.format_paint_outlined),
    ('equipements', 'Équipements', Icons.kitchen_outlined),
    ('autre', 'Autre', Icons.build_outlined),
  ];
  static const _priorities = [
    ('normale', 'Normale'),
    ('urgente', 'Urgente'),
    ('critique', 'Critique'),
  ];

  String _category = 'plomberie';
  String _priority = 'normale';
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<Uint8List> _photos = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 3) return;
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 80);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _photos.add(bytes));
  }

  Future<void> _submit() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Donnez un titre au problème.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final urls = <String>[];
      final storage = Supabase.instance.client.storage.from('maintenance-photos');
      for (var i = 0; i < _photos.length; i++) {
        final path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await storage.uploadBinary(path, _photos[i],
            fileOptions: const FileOptions(contentType: 'image/jpeg'));
        urls.add(storage.getPublicUrl(path));
      }

      await Supabase.instance.client.from('maintenance_requests').insert({
        'property_id': widget.propertyId,
        if (widget.leaseId != null) 'lease_id': widget.leaseId,
        'tenant_id': uid,
        'landlord_id': widget.landlordId,
        'category': _category,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'priority': _priority,
        'photos': urls,
      });

      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      debugPrint('Maintenance create error: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Envoi impossible : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
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
            const Text('Signaler un problème',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: _categories.map((c) {
                final sel = _category == c.$1;
                return GestureDetector(
                  onTap: () => setState(() => _category = c.$1),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          sel ? AppColors.primaryLight : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? AppColors.primary : AppColors.border,
                          width: sel ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(c.$3,
                            color: sel
                                ? AppColors.primary
                                : AppColors.textTertiary),
                        const SizedBox(height: 4),
                        Text(c.$2,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: const InputDecoration(
                  hintText: 'Titre (ex : fuite sous l\'évier)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: const InputDecoration(
                  hintText: 'Décrivez le problème...'),
            ),
            const SizedBox(height: 16),
            const Text('Priorité',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 8),
            Row(
              children: _priorities.map((p) {
                final sel = _priority == p.$1;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: p == _priorities.last ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = p.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  sel ? AppColors.primary : AppColors.border),
                        ),
                        child: Center(
                          child: Text(p.$2,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              )),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(_photos[i],
                              width: 64, height: 64, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.removeAt(i)),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_photos.length < 3)
                  GestureDetector(
                    onTap: _busy ? null : _addPhoto,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.add_a_photo_outlined,
                          color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.error,
                  )),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Envoyer le signalement',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
