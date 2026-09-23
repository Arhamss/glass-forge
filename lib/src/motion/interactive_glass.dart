import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/composition/glass_glow.dart';
import 'package:glass_forge/src/motion/glass_decay.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/motion/glass_motion_controller.dart';
import 'package:glass_forge/src/motion/glass_overdrag.dart';
import 'package:glass_forge/src/motion/glass_press_stretch.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/motion/render_glass_motion.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

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
/// InteractiveGlass(
///   child: Glass(
///     shape: GlassRoundedRectangle(radius: BorderRadius.circular(999)),
///   ),
/// )
/// ```
///
/// and a draggable, rubber-banded, flingable surface is one more argument:
///
/// ```dart
/// InteractiveGlass(
///   drag: const GlassDrag(overdrag: GlassOverdrag(limit: 80)),
///   child: Glass(
///     shape: GlassRoundedRectangle(radius: BorderRadius.circular(999)),
///   ),
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

  /// This surface's own connection to the layer's shared glow channel.
  ///
  /// Looked up in [didChangeDependencies], not cached for the widget's
  /// whole lifetime: it is an `InheritedWidget` dependency like any other,
  /// and re-reading it there is what lets this surface follow a
  /// `GlassLayer` that changes above it.
  ValueNotifier<GlassGlow>? _glowNotifier;

  /// The glow this surface itself last wrote into [_glowNotifier], if any.
  ///
  /// Compared against the channel's live value before a release clears it.
  /// See [_releaseGlow].
  GlassGlow? _lastWrittenGlow;

  /// Where the finger last was, in global (screen) coordinates.
  ///
  /// Global, not layer-local: the layer can move (scroll, animate, an
  /// ancestor's own transform) for the whole time a press is held or
  /// decaying, so converting once and caching the result would let the
  /// glow drift away from a layer that has since moved.
  /// [_layerLocalPointerPosition] re-resolves this fresh every time it is
  /// needed instead.
  Offset? _globalPointerPosition;

  /// How far the glow reaches at any press depth above zero, in logical
  /// pixels.
  ///
  /// Deliberately **not** scaled by press the way `strength` is in
  /// [_publishGlow]: see that method's own doc comment for why a radius
  /// that ramps from zero is unsafe given how the shader floors its
  /// falloff distance.
  ///
  /// Measured, not guessed. Apple describes the glow as spreading "onto any
  /// Liquid Glass elements nearby", and the point of putting it in the
  /// shader rather than painting it per shape was to reach a neighbour at
  /// all. At the 140 this started as, it did not: measured against two
  /// adjacent controls in the example, a neighbour 96 logical pixels away
  /// gained about 7/255 at its near edge and nothing at all across the rest
  /// of it — at or under the noise floor. The falloff is
  /// `(1 - smoothstep(0, radius, distance))^2`, so at 320 that same
  /// neighbour gains roughly 86/255 at its near edge, 23/255 through its
  /// middle, and is dark again by its far edge. That reads as light
  /// arriving from somewhere and falling off, which is the effect; much
  /// beyond 320 and the whole row lifts evenly, which is not.
  static const double _glowRadius = 320;

  /// How strongly the glow brightens at its centre at full press, 0 to 1.
  static const double _glowMaxStrength = 0.55;

  @override
  void initState() {
    super.initState();
    _controller = _createController()..addListener(_publishGlow);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _glowNotifier = GlassGlowScope.maybeOf(context)?.glow;
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
      // The old controller's press is about to vanish along with it, so
      // whatever it was holding on the shared glow channel has to go too
      // — otherwise a glow claimed mid-press would be stuck there forever,
      // since the controller that would eventually release it no longer
      // exists.
      _releaseGlow();
      _controller
        ..removeListener(_publishGlow)
        ..dispose();
      _controller = _createController()..addListener(_publishGlow);
      _rawDrag = Offset.zero;
    }
  }

  @override
  void dispose() {
    _releaseGlow();
    _controller.removeListener(_publishGlow);
    _controller.dispose();
    super.dispose();
  }

  Offset _constrain(Offset value) => switch (widget.drag.axis) {
    Axis.horizontal => Offset(value.dx, 0),
    Axis.vertical => Offset(0, value.dy),
    null => value,
  };

  // The press channel used to be gated on `pressScale != 1 ||
  // pressStretch.isActive`, skipping `setPressed` entirely when neither the
  // depth scale nor the reach was configured to use it — a real saving,
  // since an unused spring still costs a ticker. The touch glow below is a
  // third, unconditional consumer of the same channel: every
  // `InteractiveGlass` glows on touch regardless of `pressScale` or
  // `pressStretch`, so the channel is now always in use and the gate always
  // evaluated to `true` in every configuration that matters. Removed rather
  // than left dead.

  void _onPointerDown(PointerDownEvent event) {
    _pointersDown.add(event.pointer);
    // Recorded before the controller is touched: `setPressed` can publish
    // synchronously (Reduce Motion settles instantly), and the glow this
    // triggers needs a position to convert the moment that happens.
    _globalPointerPosition = event.position;
    _controller.setPressed(pressed: true);
    _controller.setPressAnchor(_anchorFor(event.localPosition));
  }

  void _onPointerMove(PointerMoveEvent event) {
    _globalPointerPosition = event.position;
    _controller.setPressAnchor(_anchorFor(event.localPosition));
  }

  void _onPointerUp(int pointer) {
    _pointersDown.remove(pointer);
    if (_pointersDown.isEmpty) {
      // Only when the last finger leaves: a second finger landing on a
      // surface should not un-press it when it lifts again. The glow rides
      // this same spring down to nothing — see `_publishGlow` — rather
      // than being zeroed here directly, so it decays instead of vanishing.
      _controller
        ..setPressed(pressed: false)
        ..setPressAnchor(Offset.zero);
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

  /// Whether this surface still holds [notifier]'s channel: whether it
  /// still holds exactly the value this surface itself last wrote there.
  ///
  /// The channel only ever holds one `GlassGlow`, so identity is not
  /// available to tell "still mine" from "someone else's, coincidentally
  /// equal" apart — value equality against [_lastWrittenGlow] is the best
  /// available proxy, and in practice two different surfaces' glows are
  /// never equal, since their centres differ. See [_publishGlow] and
  /// [_releaseGlow] for the two places this decides something.
  bool _ownsGlow(ValueNotifier<GlassGlow> notifier) =>
      _lastWrittenGlow != null && notifier.value == _lastWrittenGlow;

  /// Writes this surface's glow into the layer's shared channel, or lets
  /// its claim on that channel go.
  ///
  /// Called on every change of [_controller]'s value — a tick of the press
  /// spring, or a synchronous settle under Reduce Motion — which is what
  /// lets the glow track the same channel `pressAnchor` and press-stretch
  /// already read, with no ticker of its own. See the class doc comment on
  /// [GlassGlowScope] for the rule this follows when more than one surface
  /// wants the channel at once.
  ///
  /// **Design decision: a live touch always claims the channel; a
  /// decaying one never fights to reclaim it.** While a pointer is down
  /// ([_pointersDown] is non-empty) this always writes, seizing the
  /// channel from whatever it held before — "the glow follows the active
  /// touch" only means something if a fresh touch always wins. Once every
  /// pointer has lifted, [_controller]'s press spring keeps ticking this
  /// down to zero on its own, and without a check here this surface would
  /// keep re-publishing its own *fading* glow on every one of those ticks
  /// even after a different surface had since claimed the channel with a
  /// live touch of its own — clobbering it right back, one frame later,
  /// with a glow that is not even growing any more. So a surface with no
  /// pointer down only keeps updating a claim it still owns
  /// ([_ownsGlow]); the moment it does not, it stops touching the channel
  /// entirely rather than writing `GlassGlow.none()` over the new owner —
  /// which is the same "do not clobber a newer claim" rule [_releaseGlow]
  /// applies once this surface's own press finally reaches zero.
  ///
  /// Radius is held at [_glowRadius] for the whole press rather than
  /// ramping it up alongside [_glowMaxStrength]: the uniform this writes
  /// reaches a shader that floors its falloff distance at roughly one
  /// physical pixel regardless of what radius asks for, so a radius
  /// ramping up from zero in lockstep with a nonzero strength would pass
  /// through a state where a real, hard, sub-pixel dot renders under the
  /// finger before the glow has visibly opened up. Ramping strength alone
  /// against a fixed radius still reads as the glow spreading: at low
  /// strength only the pixels nearest the centre, where the falloff curve
  /// is closest to `1`, clear the threshold of visible brightening, so the
  /// lit area still grows as the press deepens — it never passes through
  /// the unsafe combination in the first place.
  void _publishGlow() {
    final press = _controller.value.press;
    if (press <= 0) {
      _releaseGlow();
      return;
    }
    final notifier = _glowNotifier;
    if (notifier == null) {
      return;
    }
    if (_pointersDown.isEmpty && !_ownsGlow(notifier)) {
      _lastWrittenGlow = null;
      return;
    }
    final centre = _layerLocalPointerPosition();
    if (centre == null) {
      return;
    }
    final next = GlassGlow(
      centre: centre,
      radius: _glowRadius,
      strength: _glowMaxStrength * press,
    );
    notifier.value = next;
    _lastWrittenGlow = next;
  }

  /// Lets this surface's claim on the shared glow channel go, if it still
  /// holds it.
  ///
  /// **Design decision: a release must not clobber a newer claim.** A
  /// `GlassLayer` holds exactly one glow for every surface beneath it, so
  /// two fingers — or a second surface pressed while this one is still
  /// decaying — contend for the same channel, and whichever wrote most
  /// recently wins (see [GlassGlowScope]'s doc comment). If this surface
  /// simply wrote `GlassGlow.none()` whenever its own press reached zero,
  /// it would blow away a glow a different surface had since claimed,
  /// because it has no way to tell the two apart. [_ownsGlow] is that
  /// check: this only clears the channel when it still holds exactly what
  /// *this* surface itself last wrote there. If something else has
  /// written since, that comparison fails, this is a no-op, and the newer
  /// claim survives untouched.
  void _releaseGlow() {
    final notifier = _glowNotifier;
    final stillOwned = notifier != null && _ownsGlow(notifier);
    _lastWrittenGlow = null;
    _globalPointerPosition = null;
    if (notifier != null && stillOwned) {
      notifier.value = const GlassGlow.none();
    }
  }

  /// [_globalPointerPosition] converted into the nearest `GlassLayer`'s own
  /// coordinate space, or null if there is no pointer down or no layer to
  /// convert against.
  ///
  /// **Design decision: layer space, not surface space.** The glow has to
  /// reach neighbouring glass, which only makes sense measured against the
  /// layer every surface in it shares — not against this surface's own
  /// laid-out box, which is what `Listener.onPointerDown/onPointerMove`
  /// hand back as `localPosition`. (`RenderGlassMotion.hitTestChildren`
  /// puts pointers back into this surface's own space via
  /// `addWithPaintTransform`, which is the wrong frame for exactly this
  /// reason.) So this starts from [_globalPointerPosition] — recorded in
  /// screen coordinates by the pointer handlers — and asks the layer's own
  /// render object to convert it, freshly, every time this is called,
  /// rather than converting once and caching the result: the layer can
  /// move (scroll, an ancestor's own animation) for the whole time a press
  /// is held or decaying, and a cached layer-local offset would silently
  /// drift away from the finger the moment that happens.
  Offset? _layerLocalPointerPosition() {
    final global = _globalPointerPosition;
    if (global == null) {
      return null;
    }
    final layer = _findAncestorLayer();
    if (layer == null) {
      return null;
    }
    return layer.globalToLocal(global);
  }

  /// Walks the render tree for the nearest enclosing `RenderGlassLayer`,
  /// the same way `RenderGlassShape._findAncestorLayer` does. The widget
  /// tree only tells this surface *whether* a layer exists above it (via
  /// `GlassGlowScope`); the render object it actually converts against has
  /// to come from the render tree, which is what will really paint.
  RenderGlassLayer? _findAncestorLayer() {
    var node = context.findRenderObject();
    while (node != null) {
      if (node is RenderGlassLayer) {
        return node;
      }
      node = node.parent;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // **Unconditional on purpose.** This used to be wrapped in
    // `if (widget.drag.enabled || widget.onTap != null)`, which made the
    // shape of this subtree depend on the parameters the widget was given:
    // swapping a `GlassDrag.none()` surface for a `GlassDrag(...)` one in
    // the same slot changed the number of elements under `Listener`, and
    // Flutter's in-place element update then crashed in
    // `RenderGlassMotion.performLayout` on `sizeAccessAllowed`. Nothing in
    // the API hinted at that, and it was reachable by any consumer who
    // makes a surface draggable in response to state.
    //
    // The gate bought nothing, and costs nothing to drop. Every callback
    // below is already individually nulled when there is nothing to
    // handle, and `GestureDetector` registers a recognizer only when at
    // least one callback of that family is non-null — so a surface with no
    // drag and no [onTap] puts nothing in the gesture arena and cannot
    // claim a gesture an ancestor would otherwise win. Hit testing is
    // unchanged too: the `Listener` below already applies [behavior] to
    // this very box unconditionally, so these extra proxies repeat a
    // decision that was already made and only lengthen the hit-test path.
    Widget result = GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onPanStart: widget.drag.enabled ? _onPanStart : null,
      onPanUpdate: widget.drag.enabled ? _onPanUpdate : null,
      onPanEnd: widget.drag.enabled ? _onPanEnd : null,
      onPanCancel: widget.drag.enabled ? _onPanCancel : null,
      child: widget.child,
    );

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
