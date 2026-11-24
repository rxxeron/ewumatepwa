import 'package:flutter/material.dart';
import '../../theme/ewu_theme_extension.dart';
import '../../theme/ewu_tokens.dart';
import 'ewu_surface_card.dart';

/// Compact bento metric tile with tabular numerals and optional tap action.
class EwuMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const EwuMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ewuColors;
    final tint = accentColor ?? colors.accent;

    return EwuSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(EwuSpace.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: colors.isDark ? 0.14 : 0.10),
                borderRadius: BorderRadius.circular(EwuRadius.chip + 2),
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: EwuSpace.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EwuText.title(colors.textPrimary, tabular: true),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EwuText.caption(colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
