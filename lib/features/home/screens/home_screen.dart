import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../shared/widgets/app_animations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        children: [
          _HeroSection(),
          _StatsStrip(),
          _ServicesSection(),
          _HowItWorksSection(),
          _DisclaimerBanner(),
          _Footer(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 720;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF5FF), Color(0xFFF6F8FB), Color(0xFFEDFAF8)],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isWide ? 88 : 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              // Live badge
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppTheme.surfaceBorder),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulseDot(color: AppTheme.success),
                      SizedBox(width: 8),
                      Text(
                        'Real-time availability across Dhaka',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Headline
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Emergency healthcare,\n'),
                      TextSpan(
                        text: 'one tap away',
                        style: TextStyle(
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.accent],
                            ).createShader(const Rect.fromLTWH(0, 0, 400, 70)),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: isWide
                      ? Theme.of(context).textTheme.displayMedium
                      : Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              const SizedBox(height: 20),

              // Subtitle
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    'Find hospital beds, ambulances, blood banks, and diagnostic tests near you. '
                    'Compare prices and book instantly — when every minute matters.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // CTAs
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/beds'),
                      icon: const Icon(Icons.bed_outlined, size: 20),
                      label: const Text('Find a Bed'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/ambulance'),
                      icon: const Icon(Icons.emergency_outlined, size: 20, color: AppTheme.danger),
                      label: const Text('Book Ambulance', style: TextStyle(color: AppTheme.textPrimary)),
                      style: OutlinedButton.styleFrom(backgroundColor: AppTheme.surface),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stats strip
// ─────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 400),
            child: Wrap(
              spacing: 56,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: const [
                _Stat(end: 4, suffix: '', label: 'Emergency services'),
                _Stat(end: 24, suffix: '/7', label: 'Always available'),
                _Stat(end: 8, suffix: '', label: 'Blood types tracked'),
                _Stat(end: 0, suffix: '৳', label: 'Booking fees'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int end;
  final String suffix;
  final String label;

  const _Stat({required this.end, required this.suffix, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedCount(
          end: end,
          suffix: suffix,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Services
// ─────────────────────────────────────────────────────────────

class _ServicesSection extends StatelessWidget {
  const _ServicesSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Text('Everything you need in an emergency',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Four critical services, one unified platform.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 44),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _ServiceCard(
                    icon: Icons.bed_outlined,
                    title: 'Emergency Beds',
                    description: 'Real-time bed availability with transparent daily pricing across hospitals.',
                    gradient: const [Color(0xFF0D5BC6), Color(0xFF3B82F6)],
                    route: '/beds',
                    delay: 0,
                  ),
                  _ServiceCard(
                    icon: Icons.emergency_outlined,
                    title: 'Ambulance',
                    description: 'Book the nearest available ambulance with upfront fare estimates.',
                    gradient: const [Color(0xFFC62828), Color(0xFFEF5350)],
                    route: '/ambulance',
                    delay: 100,
                  ),
                  _ServiceCard(
                    icon: Icons.bloodtype_outlined,
                    title: 'Blood Bank',
                    description: 'Search matching blood units across partnered blood banks instantly.',
                    gradient: const [Color(0xFFAD1457), Color(0xFFEC407A)],
                    route: '/blood',
                    delay: 200,
                  ),
                  _ServiceCard(
                    icon: Icons.science_outlined,
                    title: 'Diagnostic Tests',
                    description: 'Compare test prices and turnaround times across facilities.',
                    gradient: const [Color(0xFF00897B), Color(0xFF26C6DA)],
                    route: '/tests',
                    delay: 300,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  final String route;
  final int delay;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.route,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      delay: Duration(milliseconds: delay),
      child: HoverLift(
        child: SizedBox(
          width: 430,
          child: Material(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => context.go(route),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, size: 30, color: Colors.white),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(description, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20, color: AppTheme.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// How it works
// ─────────────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Text('How it works', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 44),
              const Wrap(
                spacing: 24,
                runSpacing: 32,
                alignment: WrapAlignment.center,
                children: [
                  _Step(
                    number: '1',
                    icon: Icons.search_rounded,
                    title: 'Search & compare',
                    description: 'Browse nearby facilities with live availability, road distances, and transparent pricing.',
                  ),
                  _Step(
                    number: '2',
                    icon: Icons.touch_app_outlined,
                    title: 'Book instantly',
                    description: 'Submit a request in seconds. The facility confirms and holds your spot with a timer.',
                  ),
                  _Step(
                    number: '3',
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Get care',
                    description: 'Track your booking status in real time until you arrive and are admitted.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String description;

  const _Step({required this.number, required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 30, color: AppTheme.primary),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                  child: Center(
                    child: Text(number,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Disclaimer + Footer
// ─────────────────────────────────────────────────────────────

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.primary),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'All prices shown are estimates provided by the organizations. '
                    'The platform assists coordination — it does not replace medical or dispatch judgment.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.textPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text('Emergency Healthcare Access Platform',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Built for Bangladesh · Powered by open data · Free to use',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 20),
              Text(
                '© 2026 Emergency Healthcare Access Platform. In an emergency, always call 999.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
