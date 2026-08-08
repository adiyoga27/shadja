import 'package:flutter/material.dart';
import 'package:shadja/core/constants/app_colors.dart';

class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _gradient;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
    _gradient = Tween<double>(begin: -1.0, end: 2.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? AppColors.shimmerBase;
    final highlight = widget.highlightColor ?? AppColors.shimmerHighlight;

    return AnimatedBuilder(
      animation: _gradient,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final width = bounds.width;
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, highlight, base],
              stops: [
                (_gradient.value - 0.3).clamp(0.0, 1.0),
                _gradient.value.clamp(0.0, 1.0),
                (_gradient.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(
              Rect.fromLTWH(0, 0, width, bounds.height),
            );
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}