import 'package:flutter/foundation.dart';

/// One destination in a `GlassTabBar`.
@immutable
class GlassTabBarItem {
  const GlassTabBarItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge = false,
  });

  final String label;

  /// Asset paths: the regular glyph at rest, the filled one when selected.
  final String icon;
  final String activeIcon;

  /// Shows a small accent dot, for something new behind the tab.
  final bool badge;
}
