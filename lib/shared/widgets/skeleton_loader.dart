import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Shimmer-style skeleton placeholder shown while content loads.
/// A single AnimationController drives a sweeping gradient via
/// ShaderMask — cheaper and cleaner-looking than a spinner.
class SkeletonLoader extends StatefulWidget {
  final Widget child;

  const SkeletonLoader({super.key, required this.child});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE8EDF4),
                Color(0xFFF4F7FB),
                Color(0xFFE8EDF4),
              ],
              stops: const [0.25, 0.5, 0.75],
              transform: _SlideGradientTransform(_controller.value * 2 - 1),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double progress;

  const _SlideGradientTransform(this.progress);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * progress, 0, 0);
  }
}

/// A grey rounded box used as a skeleton building block.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({super.key, this.width, required this.height, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF4),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

/// Pre-built skeleton mimicking a listing card, for use on
/// beds / blood / ambulance / tests listing screens.
/// The card shell stays outside the shimmer mask so only the
/// placeholder boxes animate — not the card background.
class ListingCardSkeleton extends StatelessWidget {
  const ListingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: const SkeletonLoader(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 56, height: 56, borderRadius: BorderRadius.all(Radius.circular(14))),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 220, height: 18),
                SizedBox(height: 8),
                SkeletonBox(width: 320, height: 13),
                SizedBox(height: 12),
                Row(
                  children: [
                    SkeletonBox(width: 90, height: 26, borderRadius: BorderRadius.all(Radius.circular(8))),
                    SizedBox(width: 8),
                    SkeletonBox(width: 90, height: 26, borderRadius: BorderRadius.all(Radius.circular(8))),
                    SizedBox(width: 8),
                    SkeletonBox(width: 70, height: 26, borderRadius: BorderRadius.all(Radius.circular(8))),
                  ],
                ),
              ],
            ),
          ),
          SkeletonBox(width: 80, height: 34, borderRadius: BorderRadius.all(Radius.circular(10))),
          ],
        ),
      ),
    );
  }
}

/// A column of listing card skeletons.
class ListingSkeletonList extends StatelessWidget {
  final int count;

  const ListingSkeletonList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => const ListingCardSkeleton()),
    );
  }
}
