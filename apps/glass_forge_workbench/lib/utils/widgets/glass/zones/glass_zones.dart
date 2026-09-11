import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_zone.dart';

/// Where every live kit glass layer is on screen, and whether each may keep
/// its backdrop pass.
///
/// Layers report their global bounds after each frame they appear in. A layer
/// whose bounds meet a higher-priority layer's must render static until they
/// part, which keeps the screen to one pass at any point.
class GlassZones extends ChangeNotifier {
  final Map<Object, GlassZone> _zones = {};
  bool _forceStatic = false;

  /// Every kit layer renders static while this is set. Reduce Transparency
  /// drives it, so the accessibility fallback and the device workaround are
  /// the same code path.
  bool get forceStatic => _forceStatic;
  set forceStatic(bool value) {
    if (value == _forceStatic) return;
    _forceStatic = value;
    notifyListeners();
  }

  void report(Object owner, Rect globalRect, GlassPriority priority) {
    final zone = GlassZone(globalRect, priority);
    if (_zones[owner] == zone) return;
    _zones[owner] = zone;
    notifyListeners();
  }

  void withdraw(Object owner) {
    if (_zones.remove(owner) != null) notifyListeners();
  }

  /// Whether [owner], at [globalRect], overlaps a layer that outranks it.
  bool mustYield(Object owner, Rect globalRect, GlassPriority priority) {
    for (final entry in _zones.entries) {
      if (identical(entry.key, owner)) continue;
      final other = entry.value;
      if (other.priority.index <= priority.index) continue;
      final overlap = other.rect.intersect(globalRect);
      if (overlap.width > 0 && overlap.height > 0) return true;
    }
    return false;
  }
}
