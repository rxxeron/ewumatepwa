import 'package:flutter/material.dart';

/// Single-controller staggered entrance for a list of children using GPU-composited
/// FadeTransition + SlideTransition + subtle ScaleTransition.
class EwuStaggeredColumn extends StatefulWidget {
  final List<Widget> children;
  final Duration totalDuration;
  final CrossAxisAlignment crossAxisAlignment;
  final double slideOffsetY;

  const EwuStaggeredColumn({
    super.key,
    required this.children,
    this.totalDuration = const Duration(milliseconds: 520),
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.slideOffsetY = 0.05,
  });

  @override
  State<EwuStaggeredColumn> createState() => _EwuStaggeredColumnState();
}

class _EwuStaggeredColumnState extends State<EwuStaggeredColumn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) || widget.children.isEmpty) {
      return Column(
        crossAxisAlignment: widget.crossAxisAlignment,
        children: widget.children,
      );
    }

    final count = widget.children.length;
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      children: List.generate(count, (index) {
        final start = (index * 0.08).clamp(0.0, 0.55);
        final end = (start + 0.45).clamp(0.0, 1.0);
        final curve = CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        );

        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, widget.slideOffsetY),
              end: Offset.zero,
            ).animate(curve),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(curve),
              child: widget.children[index],
            ),
          ),
        );
      }),
    );
  }
}

/// GPU-composited pulsing status dot for live classes and active indicators.
class EwuPulseDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool animate;

  const EwuPulseDot({
    super.key,
    required this.color,
    this.size = 8.0,
    this.animate = true,
  });

  @override
  State<EwuPulseDot> createState() => _EwuPulseDotState();
}

class _EwuPulseDotState extends State<EwuPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EwuPulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!widget.animate || reduce) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      );
    }

    return SizedBox(
      width: widget.size * 1.8,
      height: widget.size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.45, end: 0.0).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.8).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOut),
              ),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ),
          ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Smooth numeric count-up for CGPA, percentages, and credit totals.
class EwuAnimatedCounter extends StatelessWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle style;
  final Duration duration;

  const EwuAnimatedCounter({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.duration = const Duration(milliseconds: 650),
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(formatter(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(formatter(animatedValue), style: style);
      },
    );
  }
}
