import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';

/// One destination of the floating bottom bar.
class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;
}

/// Pill-shaped floating bottom navigation bar with a raised center button.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    required this.items,
    this.centerIcon = Icons.shopping_bag_outlined,
    this.centerBadgeCount = 0,
    this.centerEnabled = true,
    this.onCenterTap,
    this.visible = true,
    super.key,
  });

  /// Height reserved for content bottom padding (pill + margins).
  static const double height = 96;

  final List<FloatingNavItem> items;
  final IconData centerIcon;
  final int centerBadgeCount;
  final bool centerEnabled;
  final VoidCallback? onCenterTap;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 1.5),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SizedBox(
              height: 76,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: tokens.navBackground,
                      borderRadius: BorderRadius.circular(999),
                      border:
                          dark ? Border.all(color: tokens.border) : null,
                      boxShadow: dark
                          ? null
                          : const <BoxShadow>[
                              BoxShadow(
                                blurRadius: 24,
                                offset: Offset(0, 8),
                                color: Color(0x14000000),
                              ),
                            ],
                    ),
                    child: Row(
                      children: <Widget>[
                        for (int i = 0; i < items.length; i++) ...<Widget>[
                          if (i == items.length ~/ 2)
                            const SizedBox(width: 72),
                          Expanded(child: _NavItem(item: items[i])),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    child: _CenterButton(
                      icon: centerIcon,
                      badgeCount: centerBadgeCount,
                      enabled: centerEnabled,
                      onTap: onCenterTap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.item});

  final FloatingNavItem item;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color color =
        item.selected ? Theme.of(context).colorScheme.primary : tokens.textTertiary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        AppHaptics.light();
        item.onTap();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Badge(
            isLabelVisible: item.badgeCount > 0,
            label: Text('${item.badgeCount}'),
            child: AnimatedScale(
              scale: item.selected ? 1.15 : 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                item.selected ? item.activeIcon : item.icon,
                color: color,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  item.selected ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({
    required this.icon,
    required this.badgeCount,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final int badgeCount;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Badge(
      isLabelVisible: badgeCount > 0,
      label: Text('$badgeCount'),
      child: Material(
        color: enabled ? scheme.primary : scheme.surfaceContainerHighest,
        elevation: 6,
        shadowColor: scheme.primary.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled
              ? () {
                  AppHaptics.medium();
                  onTap?.call();
                }
              : null,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              icon,
              color: enabled
                  ? scheme.onPrimary
                  : Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
