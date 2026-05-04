import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Des milliers de biens\nà portée de main',
      subtitle: 'Appartements, villas, studios partout\nau Cameroun',
      illustrationWidget: const _CameroonMapIllustration(),
      isLastPage: false,
    ),
    OnboardingData(
      title: 'Payez en toute\nsécurité',
      subtitle:
          'Mobile Money, séquestre automatique,\nquittances numériques instantanées',
      illustrationWidget: const _PaymentIllustration(),
      isLastPage: false,
    ),
    OnboardingData(
      title: "L'immobilier\nintelligent",
      subtitle:
          'Prix optimisés par IA, score de confiance\nlocataire, alertes personnalisées',
      illustrationWidget: const _AnalyticsIllustration(),
      isLastPage: true,
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header avec bouton Passer
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: _currentPage < _pages.length - 1
                    ? TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(
                          'Passer',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : const SizedBox(height: 40),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPage(data: _pages[index]);
                },
              ),
            ),

            // Indicateur + Bouton
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: AppColors.primary,
                      dotColor: AppColors.border,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1
                                ? 'Commencer'
                                : 'Suivant',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward,
                              color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                  if (_currentPage == _pages.length - 1) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        "J'ai déjà un compte",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  if (_currentPage == 1) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        "Passer l'introduction",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page individuelle ───────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(flex: 5, child: data.illustrationWidget),
          const SizedBox(height: 32),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Illustration 1 : Carte du Cameroun ──────────────────────────────────────

class _CameroonMapIllustration extends StatelessWidget {
  const _CameroonMapIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: _CameroonMapPainter(),
          child: const SizedBox(
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}

class _CameroonMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fond noir déjà géré par le container

    // Silhouette du Cameroun (jaune)
    final mapPaint = Paint()
      ..color = const Color(0xFFFFCC00)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.08)
      ..lineTo(size.width * 0.62, size.height * 0.12)
      ..lineTo(size.width * 0.68, size.height * 0.22)
      ..lineTo(size.width * 0.72, size.height * 0.35)
      ..lineTo(size.width * 0.65, size.height * 0.48)
      ..lineTo(size.width * 0.68, size.height * 0.62)
      ..lineTo(size.width * 0.60, size.height * 0.78)
      ..lineTo(size.width * 0.48, size.height * 0.85)
      ..lineTo(size.width * 0.36, size.height * 0.80)
      ..lineTo(size.width * 0.28, size.height * 0.65)
      ..lineTo(size.width * 0.30, size.height * 0.50)
      ..lineTo(size.width * 0.28, size.height * 0.38)
      ..lineTo(size.width * 0.35, size.height * 0.22)
      ..lineTo(size.width * 0.42, size.height * 0.12)
      ..close();

    canvas.drawPath(path, mapPaint);

    // Points des villes
    final dotPaint = Paint()
      ..color = const Color(0xFF1D9E75)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = const Color(0xFF1D9E75).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final cities = [
      Offset(size.width * 0.50, size.height * 0.42), // Yaoundé
      Offset(size.width * 0.35, size.height * 0.55), // Douala
      Offset(size.width * 0.44, size.height * 0.60), // Bafoussam
    ];

    for (final city in cities) {
      // Halo
      canvas.drawCircle(city, 10, glowPaint);
      // Point principal
      canvas.drawCircle(city, 6, dotPaint);
      // Centre blanc
      canvas.drawCircle(
        city,
        2,
        Paint()..color = Colors.white,
      );
    }

    // Texte "SAFE WORK" en bas
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'SAFE WORK',
        style: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 11,
          fontFamily: 'Poppins',
          letterSpacing: 3,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        size.height * 0.90,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Illustration 2 : Paiement Mobile Money ──────────────────────────────────

class _PaymentIllustration extends StatelessWidget {
  const _PaymentIllustration();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _PaymentOptionTile(
                    color: const Color(0xFFFFCC00),
                    label: 'MTN',
                    subtitle: 'Mobile Money',
                    textColor: Colors.black,
                  ),
                  const SizedBox(height: 10),
                  _PaymentOptionTile(
                    color: const Color(0xFFFF6600),
                    label: 'OM',
                    subtitle: 'Orange Money',
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 8),
                        const Text(
                          'PAYER 150.000 FCFA',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  final Color color;
  final String label;
  final String subtitle;
  final Color textColor;

  const _PaymentOptionTile({
    required this.color,
    required this.label,
    required this.subtitle,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 6,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.radio_button_unchecked,
              color: AppColors.border, size: 18),
        ],
      ),
    );
  }
}

// ─── Illustration 3 : Analytics ──────────────────────────────────────────────

class _AnalyticsIllustration extends StatelessWidget {
  const _AnalyticsIllustration();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Card Analytics principale
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI ANALYSIS',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                            letterSpacing: 1,
                          ),
                        ),
                        const Text(
                          'Marché de Douala',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '+12.4%',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 80,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _MiniChartPainter(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2 mini cards côte à côte
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          color: Colors.white, size: 22),
                      const SizedBox(height: 8),
                      Text(
                        'TRUST SCORE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 9,
                          fontFamily: 'Poppins',
                          letterSpacing: 1,
                        ),
                      ),
                      const Text(
                        '98%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_outlined,
                            size: 28,
                            color: AppColors.textPrimary,
                          ),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Alertes\nImmédiates',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fond sombre
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(10),
      ),
      Paint()..color = AppColors.primaryDark,
    );

    // Barres
    final barPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final barCount = 8;
    final barWidth = (size.width - 16) / barCount - 4;
    final heights = [0.4, 0.6, 0.5, 0.75, 0.55, 0.8, 0.65, 0.9];

    for (int i = 0; i < barCount; i++) {
      final x = 8 + i * (barWidth + 4);
      final barHeight = size.height * heights[i] * 0.8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            size.height - barHeight - 4,
            barWidth,
            barHeight,
          ),
          const Radius.circular(3),
        ),
        barPaint,
      );
    }

    // Courbe par dessus
    final linePaint = Paint()
      ..color = const Color(0xFF4FFFB0)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < barCount; i++) {
      final x = 8 + i * (barWidth + 4) + barWidth / 2;
      final y = size.height - (size.height * heights[i] * 0.8) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = 8 + (i - 1) * (barWidth + 4) + barWidth / 2;
        final prevY =
            size.height - (size.height * heights[i - 1] * 0.8) - 4;
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Modèle de données ────────────────────────────────────────────────────────

class OnboardingData {
  final String title;
  final String subtitle;
  final Widget illustrationWidget;
  final bool isLastPage;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.illustrationWidget,
    required this.isLastPage,
  });
}