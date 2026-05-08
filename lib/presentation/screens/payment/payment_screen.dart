import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_theme.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final leaseForPaymentProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, leaseId) async {
  final response = await Supabase.instance.client
      .from('leases')
      .select('''
        *,
        properties(
          title, neighborhood, city, monthly_rent,
          property_images(url, is_primary)
        )
      ''')
      .eq('id', leaseId)
      .maybeSingle();
  return response as Map<String, dynamic>?;
});

// ─── PaymentScreen ────────────────────────────────────────────────────────────

class PaymentScreen extends ConsumerStatefulWidget {
  final String leaseId;
  const PaymentScreen({super.key, required this.leaseId});

  @override
  ConsumerState<PaymentScreen> createState() =>
      _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _selectedMethod = 'mtn_momo';
  bool _isProcessing = false;

  String _formatPrice(num price) {
    return price
        .toInt()
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  String _getCurrentMonth() {
    final now = DateTime.now();
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre',
      'Décembre'
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  String _getPaymentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _initiatePayment(
      Map<String, dynamic> lease) async {
    setState(() => _isProcessing = true);

    try {
      final property =
          lease['properties'] as Map<String, dynamic>?;
      final rent = lease['monthly_rent'] as num? ?? 0;
      final fees = (rent * 0.015).round();
      final total = rent.toInt() + fees;

      // Appel Edge Function
      final response =
          await Supabase.instance.client.functions.invoke(
        'initiate_payment',
        body: {
          'lease_id': widget.leaseId,
          'amount': rent.toInt(),
          'payment_month': _getPaymentMonth(),
          'payment_method': _selectedMethod,
        },
      );

      final data = response.data as Map<String, dynamic>?;

      if (data?['success'] == true) {
        final paymentUrl = data?['payment_url'] as String?;
        final paymentId = data?['payment_id'] as String?;

        if (paymentUrl != null && mounted) {
          // Ouvrir WebView CinetPay
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _CinetPayWebView(
                paymentUrl: paymentUrl,
                paymentId: paymentId ?? '',
                onSuccess: () {
                  if (mounted) {
                    context.go(
                      '/payment-confirmation?paymentId=${paymentId ?? ''}',
                    );
                  }
                },
                onFailure: () {
                  if (mounted) {
                    _showError(
                        'Paiement annulé ou échoué.');
                  }
                },
              ),
            ),
          );
        }
      } else {
        final error = data?['error'] as String? ??
            'Erreur lors de l\'initiation du paiement';
        _showError(error);
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      _showError(
          'Erreur de connexion. Vérifiez votre réseau.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
          ),
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

  @override
  Widget build(BuildContext context) {
    final leaseAsync =
        ref.watch(leaseForPaymentProvider(widget.leaseId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: leaseAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
        error: (e, __) {
          debugPrint('Lease error: $e');
          return const Center(
            child: Text('Bail introuvable'),
          );
        },
        data: (lease) {
          if (lease == null) {
            return const Center(
              child: Text('Bail introuvable'),
            );
          }

          final property =
              lease['properties'] as Map<String, dynamic>?;
          final rent = lease['monthly_rent'] as num? ?? 0;
          final fees = (rent * 0.015).round();
          final total = rent.toInt() + fees;

          return Column(
            children: [
              // Header
              _buildHeader(context),

              // Contenu scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // Card bien
                      _PropertyPaymentCard(
                        property: property,
                        rent: rent,
                        month: _getCurrentMonth(),
                        formatPrice: _formatPrice,
                      ),

                      const SizedBox(height: 24),

                      // Mode de paiement
                      const Text(
                        'MODE DE PAIEMENT',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // MTN MoMo
                      _PaymentMethodCard(
                        logo: _MTNLogo(),
                        title: 'MTN MoMo',
                        subtitle: 'Paiement instantané',
                        value: 'mtn_momo',
                        selected: _selectedMethod == 'mtn_momo',
                        selectedColor:
                            const Color(0xFFFFCC00),
                        bgColor: const Color(0xFFFFFBE6),
                        onTap: () => setState(
                          () => _selectedMethod = 'mtn_momo',
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Orange Money
                      _PaymentMethodCard(
                        logo: _OrangeLogo(),
                        title: 'Orange Money',
                        subtitle: 'Sécurisé & Rapide',
                        value: 'orange_money',
                        selected:
                            _selectedMethod == 'orange_money',
                        selectedColor:
                            const Color(0xFFFF6600),
                        bgColor: const Color(0xFFFFF0E6),
                        onTap: () => setState(
                          () =>
                              _selectedMethod = 'orange_money',
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Détails facture
                      _InvoiceDetails(
                        rent: rent,
                        fees: fees,
                        total: total,
                        formatPrice: _formatPrice,
                        month: _getCurrentMonth(),
                      ),

                      const SizedBox(height: 16),

                      // Note sécurité
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Paiement sécurisé via CinetPay',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bouton payer sticky
              _PayButton(
                total: total,
                isProcessing: _isProcessing,
                formatPrice: _formatPrice,
                onPay: () => _initiatePayment(lease),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user =
        Supabase.instance.client.auth.currentUser;
    final avatarUrl =
        user?.userMetadata?['avatar_url'] as String?;

    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
                onPressed: () => context.pop(),
              ),
              const Expanded(
                child: Text(
                  'Payer mon loyer',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                ),
              ),
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
                        size: 20,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card bien ────────────────────────────────────────────────────────────────

class _PropertyPaymentCard extends StatelessWidget {
  final Map<String, dynamic>? property;
  final num rent;
  final String month;
  final String Function(num) formatPrice;

  const _PropertyPaymentCard({
    required this.property,
    required this.rent,
    required this.month,
    required this.formatPrice,
  });

  String get _imageUrl {
    final images = property?['property_images'] as List?;
    if (images != null && images.isNotEmpty) {
      final primary = images.firstWhere(
        (img) => (img as Map)['is_primary'] == true,
        orElse: () => images.first,
      );
      return (primary as Map)['url'] as String? ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _imageUrl.isNotEmpty
                ? Image.network(
                    _imageUrl,
                    width: 80,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _ImagePlaceholder(),
                  )
                : _ImagePlaceholder(),
          ),

          const SizedBox(width: 14),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property?['title'] as String? ??
                      'Mon logement',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        '${property?['neighborhood'] ?? ''}, ${property?['city'] ?? ''}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Montant + période
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatPrice(rent)}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const Text(
                'FCFA',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                month.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 70,
      color: AppColors.surfaceVariant,
      child: const Icon(
        Icons.home_rounded,
        color: AppColors.border,
        size: 28,
      ),
    );
  }
}

// ─── Card méthode de paiement ─────────────────────────────────────────────────

class _PaymentMethodCard extends StatelessWidget {
  final Widget logo;
  final String title;
  final String subtitle;
  final String value;
  final bool selected;
  final Color selectedColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.logo,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.selectedColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? bgColor : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? selectedColor
                : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            // Logo
            logo,

            const SizedBox(width: 14),

            // Texte
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
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Radio
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? selectedColor
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? selectedColor
                      : AppColors.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.circle,
                      size: 10,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logos opérateurs ─────────────────────────────────────────────────────────

class _MTNLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC00),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'MTN',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _OrangeLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6600),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'OM',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Détails facture ──────────────────────────────────────────────────────────

class _InvoiceDetails extends StatelessWidget {
  final num rent;
  final int fees;
  final int total;
  final String month;
  final String Function(num) formatPrice;

  const _InvoiceDetails({
    required this.rent,
    required this.fees,
    required this.total,
    required this.month,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Text(
                'DÉTAILS DE LA FACTURE',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Loyer
          _InvoiceLine(
            label: 'Loyer ($month)',
            amount: '${formatPrice(rent)} FCFA',
            isAccent: false,
          ),

          const SizedBox(height: 10),

          // Frais
          _InvoiceLine(
            label: 'Frais de service (1.5%)',
            amount: '${formatPrice(fees)} FCFA',
            isAccent: true,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.borderLight),
          ),

          // Total
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total à payer',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${formatPrice(total)} FCFA',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Note séquestre
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fonds sécurisés 48h avant versement au propriétaire',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.primary,
                      height: 1.4,
                    ),
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

class _InvoiceLine extends StatelessWidget {
  final String label;
  final String amount;
  final bool isAccent;

  const _InvoiceLine({
    required this.label,
    required this.amount,
    required this.isAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isAccent
                ? AppColors.accent
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Bouton Payer ─────────────────────────────────────────────────────────────

class _PayButton extends StatelessWidget {
  final int total;
  final bool isProcessing;
  final String Function(num) formatPrice;
  final VoidCallback onPay;

  const _PayButton({
    required this.total,
    required this.isProcessing,
    required this.formatPrice,
    required this.onPay,
  });

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
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isProcessing ? null : onPay,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor:
                AppColors.primary.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: isProcessing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Text(
                      'Payer ${formatPrice(total)} FCFA',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── WebView CinetPay ─────────────────────────────────────────────────────────

class _CinetPayWebView extends StatefulWidget {
  final String paymentUrl;
  final String paymentId;
  final VoidCallback onSuccess;
  final VoidCallback onFailure;

  const _CinetPayWebView({
    required this.paymentUrl,
    required this.paymentId,
    required this.onSuccess,
    required this.onFailure,
  });

  @override
  State<_CinetPayWebView> createState() =>
      _CinetPayWebViewState();
}

class _CinetPayWebViewState
    extends State<_CinetPayWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) =>
              setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            // Détecter succès ou échec
            if (request.url.contains('payment/success') ||
                request.url
                    .contains('email-confirmed')) {
              widget.onSuccess();
              Navigator.pop(context);
              return NavigationDecision.prevent;
            }
            if (request.url.contains('payment/cancel') ||
                request.url.contains('payment/failed')) {
              widget.onFailure();
              Navigator.pop(context);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.close,
              color: Colors.white),
          onPressed: () {
            widget.onFailure();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Paiement CinetPay',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}