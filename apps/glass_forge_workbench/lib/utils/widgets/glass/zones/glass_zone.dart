import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';

/// One kit layer's footprint: where it is on screen, and how much it outranks.
@immutable
class GlassZone {
  const GlassZone(this.rect, this.priority);

  final Rect rect;
  final GlassPriority priority;

  @override
  bool operator ==(Object other) =>
      other is GlassZone && other.rect == rect && other.priority == priority;

  @override
  int get hashCode => Object.hash(rect, priority);
}
