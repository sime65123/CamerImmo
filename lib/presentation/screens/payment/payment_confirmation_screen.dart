import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

final paymentConfirmationProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, paymentId) async {
  if (paymentId.isEmpty) return null;
  final response = await Supabase.instance.client
      .from('payments')
      .select('''
        *,
        leases(
          properties(title, neighborhood, city,
            property_images(url, is_primary))
        )
      ''')
      .eq('id', paymentId)
      .maybeSingle();
  return response as Map<String, dynamic>?;
});

class PaymentConfirmationScreen extends ConsumerStatefulWidget {
  final String paymentId;
  const PaymentConfirmationScreen(
      {super.key, required this.paymentId});

  @override
  ConsumerState<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState
    extends ConsumerState<PaymentConfirmationScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _scaleController;
  late Animation<double> _checkAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    );

    // Démarrer animations
    Future.delayed(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _checkController.forward();
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _scaleController.dispose();
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
    final paymentAsync = ref.watch(
      paymentConfirmationProvider(widget.paymentId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: paymentAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          ),
          error: (_, __) => _buildContent(null),
          data: (payment) => _buildContent(payment),
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic>? payment) {
    final amount = payment?['amount'] as num? ?? 0;
    final fees = payment?['fees'] as num? ?? 0;
    final total = amount.toInt() + fees.toInt();
    final transactionId =
        payment?['cinetpay_transaction_id'] as String? ??
            '#TRX-0000000';
    final paidAt = payment?['paid_at'] as String?;
    final method =
        payment?['payment_method'] as String? ?? 'orange_money';
    final lease =
        payment?['leases'] as Map<String, dynamic>?;
    final property =
        lease?['properties'] as Map<String, dynamic>?;

    String dateLabel = '';
    if (paidAt != null) {
      final dt = DateTime.parse(paidAt).toLocal();
      const months = [
        'Janvier', 'Février', 'Mars', 'Avril', 'Mai',
        'Juin', 'Juillet', 'Août', 'Septembre',
        'Octobre', 'Novembre', 'Décembre'
      ];
      dateLabel =
          '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    String methodLabel = '';
    if (method == 'mtn_momo') methodLabel = 'MTN MoMo';
    if (method == 'orange_money') methodLabel = 'Orange Money';

    String imageUrl = '';
    final images = property?['property_images'] as List?;
    if (images != null && images.isNotEmpty) {
      final primary = images.firstWhere(
        (img) => (img as Map)['is_primary'] == true,
        orElse: () => images.first,
      );
      imageUrl = (primary as Map)['url'] as String? ?? '';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Bouton fermer
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => context.go('/home'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Animation succès
          ScaleTransition(
            scale: _scaleAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Cercle externe
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                // Cercle interne
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                // Cercle coche
                ScaleTransition(
                  scale: _checkAnimation,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Titre
          const Text(
            'Paiement effectué !',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Votre transaction a été validée avec succès.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // Card montant
          Container(
            width: double.infinity,
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
                Text(
                  'MONTANT TOTAL',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatPrice(total)} FCFA',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: AppColors.success,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Fonds sécurisés',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Card détails transaction
          Container(
            width: double.infinity,
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
                _TransactionRow(
                  label: 'Référence',
                  value: transactionId.length > 12
                      ? '#${transactionId.substring(0, 12).toUpperCase()}'
                      : '#$transactionId',
                  isBold: true,
                ),
                const SizedBox(height: 12),
                _TransactionRow(
                  label: 'Date',
                  value: dateLabel.isEmpty
                      ? 'Aujourd\'hui'
                      : dateLabel,
                ),
                const SizedBox(height: 12),
                _TransactionRow(
                  label: 'Méthode',
                  value: methodLabel,
                ),
                // Barre de progression séquestre
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderLight),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ProgressStep(
                        label: 'Payé',
                        isActive: true,
                        isDone: true,
                      ),
                    ),
                    _ProgressLine(isActive: true),
                    Expanded(
                      child: _ProgressStep(
                        label: 'Séquestre',
                        isActive: true,
                        isDone: false,
                      ),
                    ),
                    _ProgressLine(isActive: false),
                    Expanded(
                      child: _ProgressStep(
                        label: 'Versé',
                        isActive: false,
                        isDone: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Card bien payé
          if (property != null)
            Container(
              padding: const EdgeInsets.all(14),
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
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(
                          width: 64,
                          height: 64,
                          color: AppColors.surfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          property['title'] as String? ??
                              'Mon logement',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Paiement du loyer mensuel',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 28),

          // Bouton Retour accueil
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text(
                'Retour à l\'accueil',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Bouton Télécharger quittance
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/documents'),
              icon: const Icon(
                Icons.download_outlined,
                size: 18,
              ),
              label: const Text(
                'Télécharger la quittance',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(
                  color: AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Lien support
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Besoin d\'aide ? ',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const Text(
                'Contacter le support',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _TransactionRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: isBold
                ? FontWeight.w700
                : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDone;

  const _ProgressStep({
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.border,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDone ? Icons.check : Icons.circle,
            color: Colors.white,
            size: isDone ? 16 : 8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: isActive
                ? AppColors.primary
                : AppColors.textTertiary,
            fontWeight: isActive
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final bool isActive;
  const _ProgressLine({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 22),
        color: isActive ? AppColors.primary : AppColors.border,
      ),
    );
  }
}