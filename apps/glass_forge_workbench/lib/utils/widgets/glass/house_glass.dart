import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';

/// Hands the house material to every kit component below it, so a component
/// can default to it without depending on the cubit that owns it.
class HouseGlass extends InheritedWidget {
  const HouseGlass({required this.material, required super.child, super.key});

  final GlassMaterial material;

  /// The nearest house material, or the dome when there is none — a kit
  /// component pumped on its own in a test still renders sensibly.
  static GlassMaterial of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HouseGlass>()?.material ??
      GlassMaterial.dome();

  /// The house material with a legibility floor, for glass that carries
  /// words to read: sheets, menus, toasts.
  ///
  /// A clear dome over a busy feed magnifies the feed straight through a
  /// sheet's own text. Frost is what separates the two, so an overlay keeps
  /// at least [overlayFrost] of it whatever the house material says.
  static GlassMaterial overlayOf(BuildContext context) {
    final house = of(context);
    return house.copyWith(frost: math.max(house.frost, overlayFrost));
  }

  static const double overlayFrost = 18;

  @override
  bool updateShouldNotify(HouseGlass oldWidget) =>
      material != oldWidget.material;
}
