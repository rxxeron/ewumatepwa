import 'package:flutter/material.dart';
import '../../theme/ewu_theme_extension.dart';
import '../../theme/ewu_tokens.dart';

enum EwuBadgeVariant { filled, outline, subtle }
typedef EwuBadgeType = EwuBadgeVariant;

/// High-contrast status, room, and category badge component for fast scanning.
class EwuBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final EwuBadgeVariant variant;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const EwuBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    EwuBadgeVariant? variant,
    EwuBadgeVariant? type,
    this.fontSize = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  }) : variant = type ?? variant ?? EwuBadgeVariant.subtle;

  factory EwuBadge.room(String room, {double fontSize = 12.0}) {
    return EwuBadge(
      label: room,
      icon: Icons.meeting_room_outlined,
      variant: EwuBadgeVariant.subtle,
      fontSize: fontSize,
    );
  }

  factory EwuBadge.section(String section, {double fontSize = 12.0}) {
    return EwuBadge(
      label: section,
      icon: Icons.group_work_outlined,
      variant: EwuBadgeVariant.subtle,
      fontSize: fontSize,
    );
  }

  factory EwuBadge.status(String status, {required Color color, double fontSize = 12.0}) {
    return EwuBadge(
      label: status,
      color: color,
      variant: EwuBadgeVariant.subtle,
      fontSize: fontSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ewuColors;
    final baseColor = color ?? colors.accent;

    final Color bg;
    final Color fg;
    final Color border;

    switch (variant) {
      case EwuBadgeVariant.filled:
        bg = baseColor;
        fg = colors.isDark ? colors.bg : colors.surface;
        border = Colors.transparent;
      case EwuBadgeVariant.outline:
        bg = Colors.transparent;
        fg = baseColor;
        border = baseColor.withValues(alpha: 0.35);
      case EwuBadgeVariant.subtle:
        bg = baseColor.withValues(alpha: colors.isDark ? 0.14 : 0.10);
        fg = baseColor;
        border = baseColor.withValues(alpha: colors.isDark ? 0.26 : 0.22);
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(EwuRadius.chip),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: fg),
            const SizedBox(width: EwuSpace.xxs),
          ],
          Text(
            label,
            style: EwuText.caption(fg, weight: FontWeight.w600).copyWith(
              fontSize: fontSize < 12.0 ? 12.0 : fontSize,
            ),
          ),
        ],
      ),
    );
  }
}
