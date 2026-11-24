import 'package:flutter/material.dart';
import '../../theme/ewu_theme_extension.dart';
import '../../theme/ewu_tokens.dart';

/// Consistent section header with optional trailing action or badge.
class EwuSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const EwuSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: EwuSpace.sm),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ewuColors;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: EwuText.headline(colors.textPrimary),
            ),
          ),
          if (trailing != null) trailing!,
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: EwuText.label(colors.accent),
              ),
            ),
        ],
      ),
    );
  }
}
