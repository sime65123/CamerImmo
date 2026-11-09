import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';

/// Ouvre la feuille « Demander une visite » pour un bien.
Future<void> showVisitRequestSheet(
  BuildContext context, {
  required String propertyId,
  required String ownerId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        _VisitRequestSheet(propertyId: propertyId, ownerId: ownerId),
  );
}

class _VisitRequestSheet extends StatefulWidget {
  final String propertyId;
  final String ownerId;
  const _VisitRequestSheet({required this.propertyId, required this.ownerId});

  @override
  State<_VisitRequestSheet> createState() => _VisitRequestSheetState();
}

class _VisitRequestSheetState extends State<_VisitRequestSheet> {
  static const _slots = [
    '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00',
  ];

  late final List<DateTime> _days;
  DateTime? _day;
  String? _slot;
  final _messageCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    // 14 prochains jours, dimanche exclu
    _days = List.generate(
            15,
            (i) => DateTime(today.year, today.month, today.day)
                .add(Duration(days: i + 1)))
        .where((d) => d.weekday != DateTime.sunday)
        .take(12)
        .toList();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  static const _wd = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (uid == widget.ownerId) {
      setState(() => _error = 'C\'est votre propre bien.');
      return;
    }
    if (_day == null || _slot == null) {
      setState(() => _error = 'Choisissez un jour et une heure.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Une seule demande en attente par bien et par locataire
      final existing = await Supabase.instance.client
          .from('visit_requests')
          .select('id')
          .eq('property_id', widget.propertyId)
          .eq('tenant_id', uid)
          .eq('status', 'en_attente')
          .limit(1);
      if ((existing as List).isNotEmpty) {
        setState(() {
          _busy = false;
          _error = 'Vous avez déjà une demande de visite en attente.';
        });
        return;
      }

      await Supabase.instance.client.from('visit_requests').insert({
        'property_id': widget.propertyId,
        'tenant_id': uid,
        'landlord_id': widget.ownerId,
        'requested_date': _iso(_day!),
        'requested_time': _slot,
        'message': _messageCtrl.text.trim(),
        'status': 'en_attente',
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Demande de visite envoyée. Le propriétaire va vous répondre.',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      debugPrint('Visit request error: $e');
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
            const Text('Demander une visite',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 6),
            const Text(
              'Choisissez un créneau : le propriétaire confirme ou propose un autre moment.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Jour',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 10),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = _days[i];
                  final sel = _day == d;
                  return GestureDetector(
                    onTap: () => setState(() => _day = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 60,
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_wd[d.weekday - 1],
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: sel
                                    ? Colors.white70
                                    : AppColors.textSecondary,
                              )),
                          Text('${d.day}',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color:
                                    sel ? Colors.white : AppColors.primary,
                              )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const Text('Heure',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots.map((t) {
                final sel = _slot == t;
                return GestureDetector(
                  onTap: () => setState(() => _slot = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(t,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: sel ? Colors.white : AppColors.textSecondary,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _messageCtrl,
              maxLines: 2,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Message (optionnel)',
              ),
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
                    : const Text('Envoyer la demande',
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
