import 'package:flutter/scheduler.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/glass_inset_surface.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/glass_static_surface.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/house_glass.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_nesting.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_zones.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_zones_scope.dart';

/// The one way a kit component puts glass on screen: a `GlassLayer` sized to
/// exactly one shape, that steps down to [GlassStaticSurface] whenever a
/// layer that outranks it overlaps.
///
/// It reports its on-screen bounds once per rendered frame without ever
/// asking for one, so a caption scrolling under the tab bar goes static for
/// exactly as long as the two overlap. Hidden branches and covered routes
/// (anything under a disabled `TickerMode`) withdraw, so an off-screen tab's
/// chrome never forces a visible screen static.
class KitGlassLayer extends StatefulWidget {
  const KitGlassLayer({
    required this.priority,
    required this.shape,
    required this.child,
    this.material,
    this.insetTint,
    super.key,
  });

  final GlassPriority priority;
  final GlassShape shape;

  /// Null uses the house material.
  final GlassMaterial? material;

  /// Content drawn on the glass, clipped to [shape].
  final Widget child;

  /// The tint this surface wears when it is drawn on other glass, where it
  /// becomes a painted inset rather than a pass of its own.
  final Color? insetTint;

  @override
  State<KitGlassLayer> createState() => _KitGlassLayerState();
}

class _KitGlassLayerState extends State<KitGlassLayer> {
  final ValueNotifier<bool> _isStatic = ValueNotifier<bool>(false);

  // Keeps the child's state (a focused text field, a running animation) when
  // the surface swaps between live and static beneath it.
  final GlobalKey _childKey = GlobalKey();

  GlassZones? _zones;
  Rect? _rect;
  bool _isVisible = true;
  bool _isTracking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final zones = GlassZonesScope.maybeOf(context);
    if (!identical(zones, _zones)) {
      _zones?.removeListener(_evaluate);
      _zones?.withdraw(this);
      _rect = null;
      _zones = zones?..addListener(_evaluate);
    }
    _isVisible = TickerMode.valuesOf(context).enabled;
    if (_isVisible) {
      _startTracking();
    } else {
      _zones?.withdraw(this);
      _rect = null;
    }
    _evaluate();
  }

  @override
  void didUpdateWidget(KitGlassLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.priority != widget.priority) _rect = null;
  }

  @override
  void dispose() {
    _zones?.removeListener(_evaluate);
    _zones?.withdraw(this);
    _isStatic.dispose();
    super.dispose();
  }

  void _startTracking() {
    if (_isTracking || _zones == null) return;
    _isTracking = true;
    SchedulerBinding.instance.addPostFrameCallback(_track);
  }

  // Runs after every frame that is rendered anyway, and re-arms for the next.
  // A post-frame callback never schedules a frame of its own, so a still
  // screen costs nothing.
  void _track(Duration _) {
    final zones = _zones;
    if (!mounted || zones == null || !_isVisible) {
      _isTracking = false;
      return;
    }
    final box = context.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      if (rect != _rect) {
        _rect = rect;
        zones.report(this, rect, widget.priority);
      }
    }
    SchedulerBinding.instance.addPostFrameCallback(_track);
  }

  bool get _shouldBeStatic {
    final zones = _zones;
    final rect = _rect;
    return zones != null &&
        (zones.forceStatic ||
            (rect != null && zones.mustYield(this, rect, widget.priority)));
  }

  bool _applyScheduled = false;

  void _evaluate() {
    if (_shouldBeStatic == _isStatic.value) return;
    // Another layer can withdraw while the tree is locked — it is being
    // unmounted mid-frame — and a rebuild cannot be asked for then. So an
    // answer that changes during a frame lands just after it.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_applyScheduled) return;
      _applyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _applyScheduled = false;
        if (mounted) _isStatic.value = _shouldBeStatic;
      });
      return;
    }
    _isStatic.value = _shouldBeStatic;
  }

  @override
  Widget build(BuildContext context) {
    if (GlassNesting.isInside(context)) {
      return GlassInsetSurface(
        shape: widget.shape,
        tint: widget.insetTint,
        child: widget.child,
      );
    }
    final material = widget.material ?? HouseGlass.of(context);
    final child = GlassNesting(
      child: KeyedSubtree(key: _childKey, child: widget.child),
    );
    return ValueListenableBuilder<bool>(
      valueListenable: _isStatic,
      builder: (context, isStatic, _) => isStatic
          ? GlassStaticSurface(
              shape: widget.shape,
              material: material,
              child: child,
            )
          : GlassLayer(
              material: material,
              child: Glass(shape: widget.shape, child: child),
            ),
    );
  }
}
