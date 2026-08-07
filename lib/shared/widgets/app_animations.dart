import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Entrance animation: fades in while sliding up slightly.
/// Uses only opacity + transform, so it stays on the GPU compositor.
/// [delay] enables staggered entrances across a list of children.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.offset = 24,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = curved;
    _slide = Tween<Offset>(begin: Offset(0, widget.offset / 100), end: Offset.zero).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Hover interaction for cards: lifts up with a deeper shadow.
/// Desktop/web gets the hover effect; touch devices are unaffected.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double lift;
  final BorderRadius? borderRadius;

  const HoverLift({
    super.key,
    required this.child,
    this.lift = 4,
    this.borderRadius,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppTheme.fast,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -widget.lift : 0, 0),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
          boxShadow: _hovered ? AppTheme.cardShadowHover : AppTheme.cardShadow,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Animated number counter: counts from 0 to [end] once when built.
class AnimatedCount extends StatelessWidget {
  final int end;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCount({
    super.key,
    required this.end,
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: end.toDouble()),
      duration: duration,
      curve: Curves.easeOutExpo,
      builder: (context, value, _) => Text('${value.round()}$suffix', style: style),
    );
  }
}

/// Subtle continuous pulse for attention-drawing elements (e.g. live dots).
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({super.key, required this.color, this.size = 8});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.5,
      height: widget.size * 2.5,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size + widget.size * 1.5 * _controller.value,
                height: widget.size + widget.size * 1.5 * _controller.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.35 * (1 - _controller.value)),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ],
          );
        },
      ),
    );
  }
}
