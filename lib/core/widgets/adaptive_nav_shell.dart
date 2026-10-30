import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/utils/app_motion.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

/// Adaptive scaffold shared by the customer and owner shells.
///
/// Below [wideBreakpoint] the mobile layout is used (FloatingNavBar at the
/// bottom). On wider screens a side [NavigationRail] replaces it so the app
/// feels native on tablets and desktop instead of a stretched phone UI.
class AdaptiveNavShell extends StatelessWidget {
  const AdaptiveNavShell({
    required this.items,
    required this.child,
    this.centerIcon = Icons.shopping_bag_outlined,
    this.centerBadgeCount = 0,
    this.centerEnabled = true,
    this.centerTooltip,
    this.onCenterTap,
    this.navVisible = true,
    super.key,
  });

  /// Width (logical px) at which the side rail replaces the bottom bar.
  static const double wideBreakpoint = 840;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  final List<FloatingNavItem> items;
  final Widget child;
  final IconData centerIcon;
  final int centerBadgeCount;
  final bool centerEnabled;
  final String? centerTooltip;
  final VoidCallback? onCenterTap;
  final bool navVisible;

  @override
  Widget build(BuildContext context) {
    if (!isWide(context)) {
      return Scaffold(
        extendBody: true,
        body: child,
        bottomNavigationBar: FloatingNavBar(
          items: items,
          centerIcon: centerIcon,
          centerBadgeCount: centerBadgeCount,
          centerEnabled: centerEnabled,
          onCenterTap: onCenterTap,
          visible: navVisible,
        ),
      );
    }

    final int selected = items.indexWhere(
      (FloatingNavItem item) => item.selected,
    );
    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: selected < 0 ? null : selected,
            onDestinationSelected: (int i) {
              AppHaptics.light();
              items[i].onTap();
            },
            labelType: NavigationRailLabelType.all,
            groupAlignment: -0.85,
            leading: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RailCenterButton(
                icon: centerIcon,
                badgeCount: centerBadgeCount,
                enabled: centerEnabled,
                tooltip: centerTooltip,
                onTap: onCenterTap,
              ),
            ),
            destinations: <NavigationRailDestination>[
              for (final FloatingNavItem item in items)
                NavigationRailDestination(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  icon: Badge(
                    isLabelVisible: item.badgeCount > 0,
                    label: Text('${item.badgeCount}'),
                    child: Icon(item.icon),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: item.badgeCount > 0,
                    label: Text('${item.badgeCount}'),
                    child: Icon(item.activeIcon),
                  ),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: SafeArea(child: child)),
        ],
      ),
    );
  }
}

/// Raised center action (cart / upload) rendered inside the rail.
class _RailCenterButton extends StatelessWidget {
  const _RailCenterButton({
    required this.icon,
    required this.badgeCount,
    required this.enabled,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final int badgeCount;
  final bool enabled;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget button = Badge(
      isLabelVisible: badgeCount > 0,
      label: Text('$badgeCount'),
      child: Material(
        color: enabled ? scheme.primary : scheme.surfaceContainerHighest,
        elevation: 4,
        shadowColor: scheme.primary.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled
              ? () {
                  AppHaptics.medium();
                  onTap?.call();
                }
              : null,
          child: Tooltip(
            message: tooltip ?? '',
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                icon,
                color: enabled ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
    if (!AppMotion.enabled(context) || badgeCount <= 0) return button;
    return ElasticIn(
      key: ValueKey<int>(badgeCount),
      duration: const Duration(milliseconds: 420),
      child: button,
    );
  }
}
