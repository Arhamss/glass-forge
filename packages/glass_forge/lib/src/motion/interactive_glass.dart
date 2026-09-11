import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/motion/glass_decay.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/motion/glass_motion_controller.dart';
import 'package:glass_forge/src/motion/glass_overdrag.dart';
import 'package:glass_forge/src/motion/render_glass_motion.dart';

/// Whether a surface can be dragged, and what happens when it is let go.
@immutable
class GlassDrag {
  /// Creates a draggable surface.
  const GlassDrag({
    this.axis,
    this.overdrag = const GlassOverdrag(),
    this.returnsHome = true,
    this.decay = const GlassDecay(),
  }) : enabled = true;

  /// A surface that answers a press but stays where it was laid out.
  const GlassDrag.none()
    : enabled = false,
      axis = null,
      overdrag = const GlassOverdrag(),
      returnsHome = true,
      decay = const GlassDecay();

  /// Whether dragging is on at all.
  final bool enabled;

  /// Constrains the drag to one axis. Null lets it move freely.
  final Axis? axis;

  /// How far the surface may travel from rest, and how hard it resists.
  final GlassOverdrag overdrag;

  /// Whether letting go springs the surface back to where it was laid out.
  ///
  /// False makes it a free chip: the flick carries it under friction and it
  /// stays wherever it lands.
  final bool returnsHome;

  /// How a fling decays, when [returnsHome] is false.
  final GlassDecay decay;
}

/// Glass that answers the pointer.
///
/// The common case is one line — wrap the glass and it gains a press
/// response:
///
/// ```dart
/// InteractiveGlass(child: Glass(shape: GlassShape.capsule()))
/// ```
///
/// and a draggable, rubber-banded, flingable surface is one more argument:
///
/// ```dart
/// InteractiveGlass(
///   drag: const GlassDrag(overdrag: GlassOverdrag(limit: 80)),
///   child: Glass(shape: GlassShape.capsule()),
/// )
/// ```
///
/// Everything it does reaches the shader through the render tree, not the
/// element tree: a [GlassMotionController] drives a [RenderGlassMotion],
/// which reports its transform through `applyPaintTransform`, which is what
/// `RenderGlassShape` reads when it re-registers its geometry each paint. No
/// part of this rebuilds a widget while a spring is running.
///
/// Under the platform's Reduce Motion setting every spring here collapses to
/// an instant settle and [jiggle] stops deforming anything — the surface
/// still answers the pointer, it just stops springing about it.
class InteractiveGlass extends StatefulWidget {
  /// Creates an interactive glass surface.
  const InteractiveGlass({
    required this.child,
    this.pressScale = 0.96,
    this.drag = const GlassDrag.none(),
    this.jiggle = const GlassJiggle(),
    this.followMotion = const GlassMotion.interactive(),
    this.settleMotion = const GlassMotion.bouncy(),
    this.pressMotion = const GlassMotion.snappy(
      duration: Duration(milliseconds: 320),
    ),
    this.behavior = HitTestBehavior.opaque,
    this.onTap,
    super.key,
  }) : assert(pressScale > 0, 'a press scales a surface, it does not erase it');

  /// The glass this animates. Usually a `Glass`.
  final Widget child;

  /// What a fully pressed surface scales to. `1` disables the press
  /// response.
  ///
  /// Small on purpose. A press on glass reads as the surface settling
  /// *toward* the layer, not as a button shrinking.
  final double pressScale;

  /// Whether and how this surface can be dragged.
  final GlassDrag drag;

  /// How velocity becomes squash and stretch.
  final GlassJiggle jiggle;

  /// The spring that runs while a pointer is down.
  final GlassMotion followMotion;

  /// The spring that runs once the pointer is gone.
  final GlassMotion settleMotion;

  /// The spring the press response runs.
  final GlassMotion pressMotion;

  /// How this surface takes part in hit testing.
  final HitTestBehavior behavior;

  /// Called on a tap that was not a drag.
  final VoidCallback? onTap;

  @override
  State<InteractiveGlass> createState() => _InteractiveGlassState();
}

class _InteractiveGlassState extends State<InteractiveGlass>
    with SingleTickerProviderStateMixin {
  late GlassMotionController _controller;

  /// Pointer travel since this gesture began, before any rubber band.
  ///
  /// Accumulated rather than read back off the controller: the controller's
  /// position is the *banded* one, and feeding a banded displacement back in
  /// as a raw one would compound the resistance on every frame until the
  /// surface stopped moving at all.
  Offset _rawDrag = Offset.zero;

  final Set<int> _pointersDown = <int>{};

  @override
  void initState() {
    super.initState();
    _controller = _createController();
  }

  GlassMotionController _createController() => GlassMotionController(
    vsync: this,
    followMotion: widget.followMotion,
    settleMotion: widget.settleMotion,
    pressMotion: widget.pressMotion,
    decay: widget.drag.decay,
    overdrag: widget.drag.enabled
        ? widget.drag.overdrag
        : const GlassOverdrag.none(),
  );

  @override
  void didUpdateWidget(InteractiveGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A controller resolves its springs once, in its constructor, precisely
    // so it never touches `CupertinoMotion.description` per frame. Changing
    // the springs therefore means a new controller — and the surface snaps
    // to rest when that happens, which is why these are expected to be const
    // and are documented as tuning, not as state.
    if (oldWidget.followMotion != widget.followMotion ||
        oldWidget.settleMotion != widget.settleMotion ||
        oldWidget.pressMotion != widget.pressMotion ||
        oldWidget.drag.decay != widget.drag.decay ||
        oldWidget.drag.enabled != widget.drag.enabled ||
        oldWidget.drag.overdrag != widget.drag.overdrag) {
      _controller.dispose();
      _controller = _createController();
      _rawDrag = Offset.zero;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _constrain(Offset value) => switch (widget.drag.axis) {
    Axis.horizontal => Offset(value.dx, 0),
    Axis.vertical => Offset(0, value.dy),
    null => value,
  };

  void _onPointerDown(PointerDownEvent event) {
    _pointersDown.add(event.pointer);
    if (widget.pressScale != 1) {
      _controller.setPressed(pressed: true);
    }
  }

  void _onPointerUp(int pointer) {
    _pointersDown.remove(pointer);
    if (_pointersDown.isEmpty && widget.pressScale != 1) {
      // Only when the last finger leaves: a second finger landing on a
      // surface should not un-press it when it lifts again.
      _controller.setPressed(pressed: false);
    }
  }

  void _onPanStart(DragStartDetails details) {
    // Resume from wherever the surface actually is. Starting from zero would
    // snap a still-travelling surface back under the finger.
    _rawDrag = _controller.rawDisplacement;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _rawDrag += _constrain(details.delta);
    _controller.follow(_rawDrag);
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = _constrain(details.velocity.pixelsPerSecond);
    if (widget.drag.returnsHome) {
      _controller.release(withVelocity: velocity);
    } else {
      _controller.fling(velocity);
    }
    _rawDrag = Offset.zero;
  }

  void _onPanCancel() {
    _controller.release();
    _rawDrag = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    var result = widget.child;

    if (widget.drag.enabled || widget.onTap != null) {
      result = GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onPanStart: widget.drag.enabled ? _onPanStart : null,
        onPanUpdate: widget.drag.enabled ? _onPanUpdate : null,
        onPanEnd: widget.drag.enabled ? _onPanEnd : null,
        onPanCancel: widget.drag.enabled ? _onPanCancel : null,
        child: result,
      );
    }

    // Outside the detector and outside the arena: a press has to show the
    // instant the finger lands, not once a recognizer has won. Waiting for
    // `onTapDown` would delay every press behind the pan recognizer's own
    // decision, which is the difference between a surface that feels
    // connected and one that feels laggy.
    result = Listener(
      behavior: widget.behavior,
      onPointerDown: _onPointerDown,
      onPointerUp: (event) => _onPointerUp(event.pointer),
      onPointerCancel: (event) => _onPointerUp(event.pointer),
      child: result,
    );

    // The transform wraps the gestures, not the other way round, so hit
    // testing passes through `RenderGlassMotion`'s inverse and lands on the
    // surface where it is now rather than where it was laid out.
    return _RawGlassMotion(
      controller: _controller,
      jiggle: widget.jiggle,
      pressScale: widget.pressScale,
      child: result,
    );
  }
}

class _RawGlassMotion extends SingleChildRenderObjectWidget {
  const _RawGlassMotion({
    required this.controller,
    required this.jiggle,
    required this.pressScale,
    required Widget super.child,
  });

  final GlassMotionController controller;
  final GlassJiggle jiggle;
  final double pressScale;

  @override
  RenderGlassMotion createRenderObject(BuildContext context) {
    return RenderGlassMotion(
      controller: controller,
      jiggle: jiggle,
      pressScale: pressScale,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassMotion renderObject,
  ) {
    renderObject
      ..controller = controller
      ..jiggle = jiggle
      ..pressScale = pressScale;
  }
}
