import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/ewu_theme_extension.dart';
import '../../theme/ewu_tokens.dart';

/// A modern, tactile bento card component with crisp 1px border depth,
/// smooth spring-scale press physics, and semantic theme awareness.
class EwuSurfaceCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final Color? glowColor;
  final double glowAlpha;
  final double glowBlur;

  const EwuSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(EwuSpace.md),
    this.margin,
    this.borderRadius = EwuRadius.card,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.glowColor,
    this.glowAlpha = 0.0,
    this.glowBlur = 16.0,
  });

  @override
  State<EwuSurfaceCard> createState() => _EwuSurfaceCardState();
}

class _EwuSurfaceCardState extends State<EwuSurfaceCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ewuColors;
    final bgColor = widget.backgroundColor ?? colors.surfaceNavyBlue;
    final bColor = widget.borderColor ?? colors.borderSubtle;

    Widget cardContent = Container(
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: bColor, width: widget.borderWidth),
        boxShadow: widget.glowAlpha > 0 && widget.glowColor != null
            ? [
                BoxShadow(
                  color: widget.glowColor!.withValues(alpha: widget.glowAlpha),
                  blurRadius: widget.glowBlur,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap!();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
