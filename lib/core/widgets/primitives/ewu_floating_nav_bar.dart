import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/ewu_theme_extension.dart';
import '../../theme/ewu_tokens.dart';

class EwuNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const EwuNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Detached floating glass navigation pill with stable 5-slot layout and
/// always-visible labels for effortless scanning.
class EwuFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final List<EwuNavItem> items;

  const EwuFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ewuColors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(EwuSpace.md, 0, EwuSpace.md, EwuSpace.sm),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(EwuRadius.sheet + 4),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: EwuSpace.xs, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: colors.isDark ? 0.90 : 0.95),
                borderRadius: BorderRadius.circular(EwuRadius.sheet + 4),
                border: Border.all(color: colors.borderSubtle, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: colors.isDark ? 0.45 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;
                  return Expanded(
                    child: _NavBarItemWidget(
                      item: item,
                      isSelected: isSelected,
                      onTap: () {
                        if (!isSelected) {
                          HapticFeedback.selectionClick();
                          onItemSelected(index);
                        }
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItemWidget extends StatefulWidget {
  final EwuNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavBarItemWidget> createState() => _NavBarItemWidgetState();
}

class _NavBarItemWidgetState extends State<_NavBarItemWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.ewuColors;
    final fg = widget.isSelected ? colors.accent : colors.textSecondary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colors.accent.withValues(alpha: colors.isDark ? 0.14 : 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(EwuRadius.card + 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isSelected ? widget.item.activeIcon : widget.item.icon,
                size: 20,
                color: fg,
              ),
              const SizedBox(height: 2),
              Text(
                widget.item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EwuText.caption(
                  fg,
                  weight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
