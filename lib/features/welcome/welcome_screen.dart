// lib/features/welcome/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const Color _kBg = Color(0xFF07090F);
const Color _kCardBg = Color(0xFF111827);
const Color _kCardBorder = Color(0xFF1E2D3D);
const Color _kSubtitle = Color(0xFF94A3B8);
const Color _kDotInactive = Color(0xFF2D3748);

// ---------------------------------------------------------------------------
// WelcomeScreen
// ---------------------------------------------------------------------------

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onCriarConta;
  final VoidCallback onJaTenhoConta;

  const WelcomeScreen({
    super.key,
    required this.onCriarConta,
    required this.onJaTenhoConta,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _nextPage() {
    _pageController.animateToPage(
      _currentPage + 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _skipToLast() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const List<Color> _slideColors = [
    Color(0xFF00C98A),
    Color(0xFF0EA5E9),
    Color(0xFF818CF8),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _slideColors[_currentPage];

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Main page view ──────────────────────────────────────────────
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _Slide1(color: _slideColors[0]),
              _Slide2(color: _slideColors[1]),
              _Slide3(
                color: _slideColors[2],
                onCriarConta: widget.onCriarConta,
                onJaTenhoConta: widget.onJaTenhoConta,
              ),
            ],
          ),

          // ── "Pular" — slides 0 & 1 ──────────────────────────────────────
          if (_currentPage < 2)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: TextButton(
                    onPressed: _skipToLast,
                    child: Text(
                      'Pular',
                      style: GoogleFonts.dmSans(
                        color: _kSubtitle,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Dots + "Próximo" — slides 0 & 1 ────────────────────────────
          if (_currentPage < 2)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DotsIndicator(
                        count: 3,
                        current: _currentPage,
                        activeColor: color,
                      ),
                      const SizedBox(height: 32),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: _nextPage,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: color, width: 1.5),
                            foregroundColor: color,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Próximo',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Dots — slide 2 (buttons are inside _Slide3) ─────────────────
          if (_currentPage == 2)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 152),
                  child: _DotsIndicator(
                    count: 3,
                    current: _currentPage,
                    activeColor: color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 1 — NFS-e / serviço prestado
// ---------------------------------------------------------------------------

class _Slide1 extends StatelessWidget {
  final Color color;
  const _Slide1({required this.color});

  @override
  Widget build(BuildContext context) {
    return _SlideLayout(
      color: color,
      tag: 'NFS-e Nacional · LC 214/2025',
      icon: Icons.monitor_heart_outlined,
      headline: 'Serviço prestado.\nNFS-e emitida.',
      subtitle:
          'Plantão, cirurgia, anestesia ou laudo — 100% automatizado. Sem portais, sem burocracia.',
      extra: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CheckBadge(color: color, label: 'Serviço confirmado'),
          const SizedBox(height: 20),
          _SpecialtyPills(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 2 — cálculo de líquido
// ---------------------------------------------------------------------------

class _Slide2 extends StatelessWidget {
  final Color color;
  const _Slide2({required this.color});

  @override
  Widget build(BuildContext context) {
    return _SlideLayout(
      color: color,
      tag: 'Cálculo em tempo real',
      icon: Icons.calculate_outlined,
      headline: 'Seu líquido real,\ncalculado na hora.',
      subtitle:
          'ISS, IRPF e INSS por regime — tudo transparente antes de você receber.',
      extra: _NumericCard(),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 3 — Reforma Tributária + CTA buttons
// ---------------------------------------------------------------------------

class _Slide3 extends StatelessWidget {
  final Color color;
  final VoidCallback onCriarConta;
  final VoidCallback onJaTenhoConta;

  const _Slide3({
    required this.color,
    required this.onCriarConta,
    required this.onJaTenhoConta,
  });

  @override
  Widget build(BuildContext context) {
    return _SlideLayout(
      color: color,
      tag: 'IBS · CBS · Split Payment 2027',
      icon: Icons.shield_outlined,
      overlayIcon: Icons.check,
      headline: 'Reforma Tributária?\nJá resolvemos.',
      subtitle:
          'IBS e CBS preenchidos automaticamente. Em conformidade com a LC 214/2025 desde o primeiro dia.',
      extra: _CheckBadge(color: color, label: 'Conformidade garantida'),
      bottomButtons: _CtaButtons(
        onCriarConta: onCriarConta,
        onJaTenhoConta: onJaTenhoConta,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic slide layout
// ---------------------------------------------------------------------------

class _SlideLayout extends StatelessWidget {
  final Color color;
  final String tag;
  final IconData icon;
  final IconData? overlayIcon;
  final String headline;
  final String subtitle;
  final Widget? extra;
  final Widget? bottomButtons;

  const _SlideLayout({
    required this.color,
    required this.tag,
    required this.icon,
    this.overlayIcon,
    required this.headline,
    required this.subtitle,
    this.extra,
    this.bottomButtons,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            28,
            MediaQuery.of(context).padding.top + 64,
            28,
            bottomButtons != null ? 160 : 140,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TagPill(color: color, label: tag),
              const SizedBox(height: 36),
              _SlideIcon(color: color, icon: icon, overlayIcon: overlayIcon),
              const SizedBox(height: 32),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: _kSubtitle,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                ),
              ),
              if (extra != null) ...[
                const SizedBox(height: 28),
                extra!,
              ],
              if (bottomButtons != null) ...[
                const SizedBox(height: 36),
                bottomButtons!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tag pill
// ---------------------------------------------------------------------------

class _TagPill extends StatelessWidget {
  final Color color;
  final String label;

  const _TagPill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Icon circle (with optional overlay check icon)
// ---------------------------------------------------------------------------

class _SlideIcon extends StatelessWidget {
  final Color color;
  final IconData icon;
  final IconData? overlayIcon;

  const _SlideIcon({required this.color, required this.icon, this.overlayIcon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 48),
          ),
          if (overlayIcon != null)
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
                child: Icon(overlayIcon, color: _kBg, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Check badge
// ---------------------------------------------------------------------------

class _CheckBadge extends StatelessWidget {
  final Color color;
  final String label;

  const _CheckBadge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kCardBg,
        border: Border.all(color: _kCardBorder, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Specialty pills — slide 1 only
// ---------------------------------------------------------------------------

class _SpecialtyPills extends StatelessWidget {
  static const List<String> _labels = [
    'Plantonistas',
    'Anestesistas',
    'Cirurgiões',
    'Laudistas',
  ];

  const _SpecialtyPills();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _labels.map((label) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kCardBg,
            border: Border.all(color: _kCardBorder, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Numeric card — slide 2 only
// ---------------------------------------------------------------------------

class _NumericCard extends StatelessWidget {
  const _NumericCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: _kCardBg,
        border: Border.all(color: _kCardBorder, width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AmountColumn(
            label: 'bruto',
            amount: 'R\$ 8.500',
            amountColor: _kSubtitle,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 16, right: 16),
            child: Icon(
              Icons.arrow_forward,
              color: const Color(0xFF0EA5E9),
              size: 18,
            ),
          ),
          _AmountColumn(
            label: 'líquido',
            amount: 'R\$ 6.290',
            amountColor: const Color(0xFF0EA5E9),
          ),
        ],
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  final String label;
  final String amount;
  final Color amountColor;

  const _AmountColumn({
    required this.label,
    required this.amount,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: const Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: GoogleFonts.syne(
            color: amountColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CTA buttons — slide 3 only
// ---------------------------------------------------------------------------

class _CtaButtons extends StatelessWidget {
  final VoidCallback onCriarConta;
  final VoidCallback onJaTenhoConta;

  const _CtaButtons({
    required this.onCriarConta,
    required this.onJaTenhoConta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: onCriarConta,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C98A),
              foregroundColor: const Color(0xFF07090F),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Criar conta',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: onJaTenhoConta,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2D3748), width: 1.5),
              foregroundColor: _kSubtitle,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Já tenho conta',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Animated dots indicator
// ---------------------------------------------------------------------------

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;
  final Color activeColor;

  const _DotsIndicator({
    required this.count,
    required this.current,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? activeColor : _kDotInactive,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
