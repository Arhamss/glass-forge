import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/motion/glass_decay.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/motion/glass_motion_controller.dart';
import 'package:glass_forge/src/motion/glass_overdrag.dart';
import 'package:glass_forge/src/motion/glass_press_stretch.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
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
    this.pressStretch = const GlassPressStretch(),
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

  /// How far the surface reaches toward a held finger.
  ///
  /// Resolves to [GlassPressStretch.none] under Reduce Motion.
  final GlassPressStretch pressStretch;

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
        // Plural, not `SingleTickerProviderStateMixin`. Retuning a spring
        // replaces the controller (see `didUpdateWidget`), and therefore asks
        // for a second ticker. The single-ticker mixin asserts on that
        // unconditionally — its guard fires if a ticker was *ever* created,
        // not if one is still live, so disposing the old controller first does
        // not satisfy it — and the result was that changing any spring at
        // runtime threw "multiple tickers were created". Found by the
        // workbench's motion playground, which exists to do exactly that.
        with
        TickerProviderStateMixin {
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

  /// Whether the press channel does anything visible.
  ///
  /// It drives two independent effects — the uniform depth scale
  /// ([InteractiveGlass.pressScale]) and how far press-stretch reaches
  /// toward the anchor — so it has to spring even when
  /// [InteractiveGlass.pressScale] is `1` and depth is off, as long as a
  /// reach is still configured. Gating on `pressScale` alone left a surface
  /// with `pressScale: 1` and an active [InteractiveGlass.pressStretch]
  /// never pressing at all: the press channel would sit at `0` forever and
  /// `pressAnchor * press` would always be zero.
  bool get _pressChannelIsUsed =>
      widget.pressScale != 1 || widget.pressStretch.isActive;

  void _onPointerDown(PointerDownEvent event) {
    _pointersDown.add(event.pointer);
    if (_pressChannelIsUsed) {
      _controller.setPressed(pressed: true);
    }
    _controller.setPressAnchor(_anchorFor(event.localPosition));
  }

  void _onPointerMove(PointerMoveEvent event) {
    _controller.setPressAnchor(_anchorFor(event.localPosition));
  }

  void _onPointerUp(int pointer) {
    _pointersDown.remove(pointer);
    if (_pointersDown.isEmpty) {
      if (_pressChannelIsUsed) {
        // Only when the last finger leaves: a second finger landing on a
        // surface should not un-press it when it lifts again.
        _controller.setPressed(pressed: false);
      }
      _controller.setPressAnchor(Offset.zero);
    }
  }

  /// [localPosition], relative to this surface's own centre rather than its
  /// top-left corner.
  ///
  /// `RenderGlassMotion.hitTestChildren` hands every pointer inside it a
  /// position already put back into the box's laid-out coordinate space —
  /// that is the whole point of the inverse transform it hit-tests through
  /// — so this is stable through a drag or a press, not relative to wherever
  /// the surface currently is on screen.
  Offset _anchorFor(Offset localPosition) {
    final size = context.size ?? Size.zero;
    return localPosition - Offset(size.width / 2, size.height / 2);
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
      onPointerMove: _onPointerMove,
      onPointerUp: (event) => _onPointerUp(event.pointer),
      onPointerCancel: (event) => _onPointerUp(event.pointer),
      child: result,
    );

    // Reduce Motion neutralises the reach the same way it neutralises every
    // other spring here: press-stretch is read off `state.press`, and
    // `_settleEverythingNow` snaps that to its target instead of easing it,
    // so without this an under-Reduce-Motion press would deform at full
    // strength, just instantly instead of springing into it.
    final pressStretch = GlassReduceMotion.instance.value
        ? const GlassPressStretch.none()
        : widget.pressStretch;

    // The transform wraps the gestures, not the other way round, so hit
    // testing passes through `RenderGlassMotion`'s inverse and lands on the
    // surface where it is now rather than where it was laid out.
    return _RawGlassMotion(
      controller: _controller,
      jiggle: widget.jiggle,
      pressScale: widget.pressScale,
      pressStretch: pressStretch,
      child: result,
    );
  }
}

class _RawGlassMotion extends SingleChildRenderObjectWidget {
  const _RawGlassMotion({
    required this.controller,
    required this.jiggle,
    required this.pressScale,
    required this.pressStretch,
    required Widget super.child,
  });

  final GlassMotionController controller;
  final GlassJiggle jiggle;
  final double pressScale;
  final GlassPressStretch pressStretch;

  @override
  RenderGlassMotion createRenderObject(BuildContext context) {
    return RenderGlassMotion(
      controller: controller,
      jiggle: jiggle,
      pressScale: pressScale,
      pressStretch: pressStretch,
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
      ..pressScale = pressScale
      ..pressStretch = pressStretch;
  }
}
