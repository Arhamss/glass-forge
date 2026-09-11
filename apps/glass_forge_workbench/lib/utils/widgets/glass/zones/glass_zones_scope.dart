import 'package:flutter/widgets.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_zones.dart';

/// Hands the one [GlassZones] registry to every kit layer below it.
///
/// Not an `InheritedNotifier`: layers listen to the registry themselves and
/// rebuild only when their own live/static answer flips, rather than on every
/// frame of a scroll.
class GlassZonesScope extends InheritedWidget {
  const GlassZonesScope({required this.zones, required super.child, super.key});

  final GlassZones zones;

  static GlassZones? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassZonesScope>()?.zones;

  @override
  bool updateShouldNotify(GlassZonesScope oldWidget) =>
      zones != oldWidget.zones;
}
