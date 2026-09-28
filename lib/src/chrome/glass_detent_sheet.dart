import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/chrome/detent_geometry.dart';
import 'package:glass_forge/src/chrome/glass_detent.dart';
import 'package:glass_forge/src/chrome/glass_detent_sheet_controller.dart';
import 'package:glass_forge/src/chrome/glass_sheet_scroll_physics.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/design/glass_tokens.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';

/// A sheet that lives at the bottom of the screen and is dragged between
/// fixed heights — Apple Maps, Find My, `UISheetPresentationController`.
///
/// Not the other kind of sheet. A modal sheet is presented over a page and
/// taken away again; this one is always there, and the interesting behaviour
/// is what it does on the way up: below the top detent it floats, inset from
/// the screen's edges with a large radius on all four corners, and as it
/// rises the gap closes and the radius grows toward the display's own, so at
/// the top detent it is flush.
///
/// The morph is a function of the sheet's current height, not of which detent
/// it is heading to, which is what makes it track a finger instead of playing
/// when a detent is reached. Only the snap is discrete.
///
/// Belongs inside the screen's single `GlassLayer`, alongside whatever other
/// chrome the page has — not in a layer of its own. Where it covers other
/// glass, drive that chrome's `GlassPresence` from
/// [GlassDetentSheetController.presenceUnder] so the two hand off rather than
/// both rendering: two backdrop filters over one region is flutter#187820.
///
/// ```dart
/// GlassLayer(
///   child: Stack(
///     children: [
///       const Map(),
///       GlassDetentSheet(
///         detents: const [
///           GlassDetent.fraction(0.1),
///           GlassDetent.fraction(0.5),
///           GlassDetent.fraction(1),
///         ],
///         child: ListView(children: results),
///       ),
///     ],
///   ),
/// )
/// ```
class GlassDetentSheet extends StatefulWidget {
  /// Creates a detent sheet.
  const GlassDetentSheet({
    required this.detents,
    required this.child,
    this.initialDetent = 0,
    this.onDetentChanged,
    this.controller,
    this.backdrop,
    this.material,
    this.gap = 12,
    this.bottomGap,
    this.floatingRadius,
    this.flushRadius = 55,
    this.showHandle = true,
    this.semanticLabel,
    super.key,
  }) : assert(detents.length >= 2, 'a sheet that cannot move is a panel');

  /// The heights the sheet rests at. Resolved and sorted ascending.
  final List<GlassDetent> detents;

  /// What the sheet carries.
  final Widget child;

  /// Which detent the sheet opens at.
  final int initialDetent;

  /// Called when the resting detent changes.
  ///
  /// This, rather than [GlassDetentSheetController.onDetentChanged]: that
  /// field is a single slot, and a mounted sheet claims it for as long as it
  /// is attached to the controller — so a handler set on the controller
  /// directly is overwritten without a word, and setting one there after the
  /// sheet has mounted takes this callback out of the loop instead. The two
  /// are the same notification; only one of them has an owner.
  final ValueChanged<int>? onDetentChanged;

  /// Drives the sheet from outside. Created internally when null, and only
  /// disposed when created internally.
  final GlassDetentSheetController? controller;

  /// What is behind the sheet, where the app knows — see `GlassSurface`.
  final Color? backdrop;

  /// The sheet's material, in place of the one the sheet role resolves to.
  ///
  /// Null keeps the role's — Apple's fitted regular material at the role's
  /// blur and tint steps, which is right for a sheet of body text. An app
  /// with a look of its own names one here; the label colour, shadows and
  /// motion still come from the role.
  final GlassMaterial? material;

  /// How far the floating sheet is inset from the screen's **side** edges.
  final double gap;

  /// How far the floating sheet is inset from the screen's **bottom** edge.
  ///
  /// Null takes [gap], which is the right default for a sheet floating over
  /// nothing. Raise it above [gap] when the sheet floats over other glass —
  /// a tab bar, a toolbar — because the two must never both render over the
  /// same pixels, and the sheet clears that chrome only once this inset
  /// exceeds its height. Raising [gap] instead would buy the same clearance
  /// and charge twice its width for it: 64 pt of clearance for a 52 pt bar
  /// costs 128 pt of a phone-width sheet.
  ///
  /// Both insets close to 0 together as the sheet rises, so a flush sheet is
  /// flush on every edge however far apart they started.
  final double? bottomGap;

  /// The corner radius while floating. Null takes the theme's
  /// [GlassRadiusStep.extraLarge], which is the sheet role's own step.
  final double? floatingRadius;

  /// The corner radius when flush.
  ///
  /// Nominally the display's own corner radius, so the sheet's corners match
  /// the screen's at the top detent. No platform API exposes that number, so
  /// this defaults to 55 — what modern iPhones use — and an app that knows
  /// its device better should say so rather than accept the guess.
  final double flushRadius;

  /// Whether to draw the grab handle at the top of the sheet.
  final bool showHandle;

  /// What a screen reader calls this sheet.
  final String? semanticLabel;

  @override
  State<GlassDetentSheet> createState() => _GlassDetentSheetState();
}

// `TickerProviderStateMixin`, not `SingleTickerProviderStateMixin`, even
// though only one controller is ever live at a time. The single-ticker mixin
// never clears its `_ticker` field when that ticker is disposed, so it counts
// tickers ever created rather than tickers currently alive, and the legal
// sequence controller: null -> caller's -> null again creates a second one.
// That is two tickers by its reckoning, and it asserts.
class _GlassDetentSheetState extends State<GlassDetentSheet>
    with TickerProviderStateMixin {
  GlassDetentSheetController? _internal;

  /// An internal controller displaced by a caller's, waiting for the end of
  /// the frame to be disposed. See [didUpdateWidget].
  GlassDetentSheetController? _retiring;

  GlassDetentSheetController get _controller =>
      widget.controller ?? (_internal ??= _createController());

  List<double> _resolved = const <double>[];

  /// See [_physicsFor].
  GlassSheetScrollPhysics? _physics;

  GlassDetentSheetController _createController() =>
      GlassDetentSheetController(vsync: this);

  /// The spring this state last pushed onto the controller.
  ///
  /// Kept so a caller's own choice can be told from one this widget made.
  /// See [_syncSettleMotion].
  GlassMotion? _pushedMotion;

  @override
  void initState() {
    super.initState();
    _controller.onDetentChanged = _onDetentChanged;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSettleMotion();
  }

  /// Gives the controller the spring the theme names for the sheet role.
  ///
  /// The role's spring, not one named here: `GlassSurfaces.sheet` says a
  /// sheet moves on [GlassMotionRole.present], and the theme says what that
  /// is worth. Reading it through both is what makes a designer's retune of
  /// `GlassMotionDefaults.present` reach this sheet, which is the promise
  /// that class's own doc makes. A stiffness written out here would quietly
  /// opt the one widget with the longest travel out of it.
  ///
  /// Not through [GlassTheme.surfaceOf], although the build already resolves
  /// that style: the full resolve needs a size, and this runs before there
  /// are constraints. The spring does not depend on the size, so the role is
  /// asked for it directly.
  ///
  /// Called again on every dependency change, so a theme swapped at runtime
  /// — light to dark, a designer's live retune — retunes a sheet that is
  /// already on screen. A controller whose own
  /// [GlassDetentSheetController.settleMotion] the caller set is left alone:
  /// it holds something this widget did not put there, and that is a
  /// decision, not a default.
  void _syncSettleMotion() {
    final theme = GlassTheme.of(context);
    final motion = theme.motion.of(
      theme.surfaces.of(GlassSurfaceRole.sheet).motion,
    );
    final controller = _controller;
    if (controller.settleMotion != null &&
        controller.settleMotion != _pushedMotion) {
      return;
    }
    controller.settleMotion = motion;
    _pushedMotion = motion;
  }

  /// Hands [controller]'s spring back, if this widget is what set it.
  void _releaseSettleMotion(GlassDetentSheetController? controller) {
    if (controller != null && controller.settleMotion == _pushedMotion) {
      controller.settleMotion = null;
    }
  }

  @override
  void didUpdateWidget(GlassDetentSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    // Read before anything is torn down: which detent the sheet is showing
    // right now, from whichever controller was driving it.
    final wasAt = (oldWidget.controller ?? _internal)?.detent;

    oldWidget.controller?.onDetentChanged = null;
    _releaseSettleMotion(oldWidget.controller);
    _pushedMotion = null;
    if (widget.controller != null && _internal != null) {
      // The sheet made one before the caller supplied theirs. Nothing can
      // reach it now, and it holds a listener on the global
      // `GlassReduceMotion` that only its own dispose removes, so it is
      // retired here rather than at [dispose] — it is still a controller
      // this state created, which is the only test [dispose] applies.
      //
      // At the end of the frame, though, not now: the `AnimatedBuilder`
      // below is still subscribed to it and only detaches when the rebuild
      // this update schedules reaches it. Disposing a listenable underneath
      // a live listener happens to be survivable here, because
      // `AnimationLocalListenersMixin.removeListener` tolerates a list that
      // has already been cleared, but that is its tolerance and not this
      // widget's design. One frame is cheap.
      _retiring = _internal;
      _internal = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _disposeRetiring());
    }
    _controller.onDetentChanged = _onDetentChanged;
    _syncSettleMotion();
    if (_resolved.isNotEmpty) {
      // A controller handed over mid-life has never been told this sheet's
      // detents, and [_syncDetents] will not tell it: that only speaks up
      // when the resolved heights change, and swapping the controller does
      // not change them. Without this the sheet would drive a controller
      // that believes it has nowhere to rest.
      //
      // The index is only forced when the replacement is one this state just
      // made. A fresh internal controller has no opinion about where the
      // sheet is, so inheriting the position it is already at is the only
      // thing it can do that is not a teleport. A controller the caller
      // handed in does have an opinion — that is the whole point of handing
      // one in — so it keeps its own.
      _controller.setDetents(
        _resolved,
        initialDetent: widget.controller == null ? wasAt : null,
      );
    }
  }

  void _disposeRetiring() {
    _retiring?.dispose();
    _retiring = null;
  }

  void _onDetentChanged(int index) => widget.onDetentChanged?.call(index);

  @override
  void dispose() {
    // Only the ones this state made. A caller's controller outlives the
    // widget by construction — that is what passing one in is for.
    //
    // The retiring one goes first and synchronously: its post-frame callback
    // may not have run yet, and `TickerProviderStateMixin.dispose` asserts
    // that every ticker it handed out is already disposed.
    _disposeRetiring();
    _internal?.dispose();
    widget.controller?.onDetentChanged = null;
    _releaseSettleMotion(widget.controller);
    super.dispose();
  }

  void _syncDetents(double available) {
    // Captured before `_resolved` is reassigned below. Reading it after would
    // always be false, and `initialDetent` would never reach the controller.
    final isFirst = _resolved.isEmpty;
    final resolved = resolveGlassDetents(
      widget.detents,
      available: available,
      // Content detents measure the child. Nothing measures it yet, so a
      // `content()` detent resolves to the available height — the documented
      // fallback in `GlassDetentContent.resolve`. Wiring a real intrinsic
      // measurement is its own task.
      contentHeight: double.infinity,
    );
    if (listEquals(resolved, _resolved)) {
      return;
    }
    _resolved = resolved;
    _controller.setDetents(
      resolved,
      initialDetent: isFirst ? widget.initialDetent : null,
    );
  }

  void _stepDetent(int by) {
    final next = _clampDetent(_controller.detent + by);
    if (next != _controller.detent) {
      _controller.animateToDetent(next);
    }
  }

  int _clampDetent(int index) =>
      _resolved.isEmpty ? 0 : index.clamp(0, _resolved.length - 1);

  /// What a screen reader reads out for the detent at [index].
  ///
  /// Spelled out for the current detent *and* for the two either side,
  /// because a node that advertises an increase action has to say what
  /// increasing would produce — the framework asserts on a value without an
  /// increased value, since "adjustable" with no readable outcome is a
  /// control a screen-reader user cannot aim.
  String _detentValue(int index) =>
      '${_clampDetent(index) + 1} of ${_resolved.length}';

  void _onDragStart(DragStartDetails details) => _controller.beginDrag();

  void _onDragUpdate(DragUpdateDetails details) =>
      _controller.dragBy(-details.delta.dy);

  void _onDragEnd(DragEndDetails details) =>
      _controller.endDrag(velocity: -details.velocity.pixelsPerSecond.dy);

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final floatingRadius =
        widget.floatingRadius ??
        GlassTheme.of(
          context,
        ).tokens.radius.radiusOf(GlassRadiusStep.extraLarge);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight - padding.top;
        // Resolved here because this is where the available height exists,
        // and nowhere earlier does. That puts a controller notification
        // inside a build, which would throw on any sibling already
        // listening — so the controller holds that one notification to the
        // end of the frame. See `GlassDetentSheetController._publish`.
        _syncDetents(available);

        // Built here rather than inside the `AnimatedBuilder`, and threaded
        // down as a value. The sheet rebuilds on every frame of a drag, and
        // a `ScrollConfiguration` rebuilt that often would hand a descendant
        // `Scrollable` a new `ScrollBehavior` each frame, which is a changed
        // dependency, which recreates its `ScrollPosition` — underneath the
        // very drag this class exists to route. Hoisting it makes the widget
        // identical across those rebuilds, and an identical widget is a
        // subtree `Element.updateChild` skips outright.
        final content = _buildContent(context);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final metrics = GlassDetentSheetMetrics.at(
              height: _controller.value,
              lowest: _controller.lowest,
              top: _controller.top,
              gap: widget.gap,
              bottomGap: widget.bottomGap,
              floatingRadius: floatingRadius,
              flushRadius: widget.flushRadius,
            );
            return Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: metrics.gap,
                  right: metrics.gap,
                  // The gap, plus as much of the bottom safe-area inset as
                  // the sheet is not yet carrying itself. A floating sheet
                  // sits clear of the home indicator entirely; a flush one
                  // runs to the screen's edge and pads its content instead
                  // (see [_buildSheet]). Splitting the inset by [progress]
                  // rather than switching at the top detent is what keeps
                  // the content's bottom edge continuous: the two halves
                  // always sum to the whole inset, so nothing jumps on the
                  // frame the sheet arrives.
                  bottom:
                      metrics.bottomGap +
                      padding.bottom * (1 - metrics.progress),
                ),
                child: SizedBox(
                  height: metrics.height,
                  child: _buildSheet(
                    context,
                    constraints,
                    metrics,
                    padding,
                    content,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// The caller's child, with everything that must reach it from the sheet.
  ///
  /// The `ScrollConfiguration` is how [GlassSheetScrollPhysics] gets onto a
  /// scrollable the caller wrote and this widget never sees: descendants read
  /// their physics from the behaviour above them, so installing them here
  /// needs no lookup, no attachment call and nothing from the caller. The
  /// ambient behaviour is copied rather than replaced, so scrollbars, the
  /// overscroll indicator and the platform's own physics — which become this
  /// one's parent — all survive.
  Widget _buildContent(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return GlassDetentSheetScope(
      controller: _controller,
      child: ScrollConfiguration(
        behavior: behavior.copyWith(
          physics: _physicsFor(behavior.getScrollPhysics(context)),
        ),
        child: widget.child,
      ),
    );
  }

  /// The one [GlassSheetScrollPhysics] instance this sheet hands out.
  ///
  /// Kept across rebuilds, not rebuilt with the widget, and both halves of
  /// that matter.
  ///
  /// The physics carries the identity of whichever scrollable is currently
  /// dragging the sheet — a mid-gesture fact. A fresh instance per build
  /// would arrive not knowing it, and since
  /// `_WrappedScrollBehavior.shouldNotify` compares its `physics` by
  /// identity, a fresh instance is also a changed dependency, so
  /// `ScrollableState.didChangeDependencies` would swap the
  /// `ScrollPosition` for a new one carrying the new, empty physics. The old
  /// one would be left holding the live drag with nothing referencing it, and
  /// the release would reach the new physics, which would decline to end a
  /// drag it has no record of — leaving the controller dragging forever and
  /// the sheet parked between detents. The sheet rebuilds on every frame of
  /// its own animation, so this is not a rare window.
  ///
  /// Reused only while it is still the right object: a swapped controller or
  /// a different ambient physics (a platform change) rebuilds it, and neither
  /// happens inside a gesture.
  GlassSheetScrollPhysics _physicsFor(ScrollPhysics parent) {
    final existing = _physics;
    if (existing != null &&
        identical(existing.controller, _controller) &&
        identical(existing.parent, parent)) {
      return existing;
    }
    return _physics = GlassSheetScrollPhysics(
      controller: _controller,
      parent: parent,
    );
  }

  Widget _buildSheet(
    BuildContext context,
    BoxConstraints constraints,
    GlassDetentSheetMetrics metrics,
    EdgeInsets padding,
    Widget content,
  ) {
    // The role's style, but not the role's shape: the radius morphs
    // continuously, and the ladder has steps. Everything else — material,
    // shadows, the vibrant label colour — comes from the role as it should.
    //
    // Measured from the incoming constraints rather than from the window:
    // the two agree for a sheet in a `Stack` that fills the screen, which is
    // the usual arrangement, and only the constraints are right for one in a
    // narrower host. The resolved style depends on the size it is asked
    // about, so guessing wide there is a real difference, not a rounding.
    final style = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.sheet,
      size: Size(constraints.maxWidth - metrics.gap * 2, metrics.height),
      backdrop: widget.backdrop,
    );

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: _detentValue(_controller.detent),
      increasedValue: _detentValue(_controller.detent + 1),
      decreasedValue: _detentValue(_controller.detent - 1),
      onIncrease: () => _stepDetent(1),
      onDecrease: () => _stepDetent(-1),
      child: Glass(
        shape: GlassRoundedRectangle(
          radius: BorderRadius.circular(metrics.radius),
        ),
        material: widget.material ?? style.material,
        // The drag detector sits *inside* the glass, not around it. Only
        // this order puts the surface itself on the hit-test path: a `Glass`
        // whose children all decline a hit adds nothing of its own, and a
        // sheet no hit test ever names is one no test — and no future
        // gesture that wants to ask what it landed on — can find.
        //
        // It is not quite the same target, and the difference is the
        // rounded corners: inside, the detector is clipped to the shape, so
        // the four corner offcuts outside the radius no longer start a drag.
        // They are a few square points of a surface whose whole face is
        // draggable, and losing them is the price of being findable.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          onVerticalDragCancel: _controller.endDrag,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: style.labelColor),
            child: IconTheme.merge(
              data: IconThemeData(color: style.labelColor),
              child: Column(
                children: <Widget>[
                  if (widget.showHandle) _Handle(color: style.labelColor),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: Padding(
                        // The other half of the bottom safe-area inset. The
                        // sheet's own offset carries `1 - progress` of it
                        // while it floats clear of the home indicator; this
                        // takes over the rest as it settles flush and the
                        // sheet's box reaches the screen's edge.
                        padding: EdgeInsets.only(
                          bottom: padding.bottom * metrics.progress,
                        ),
                        child: content,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carries a [GlassDetentSheet]'s controller down to its content.
///
/// For the *caller's* widgets, not for this package's own plumbing. The
/// scroll handoff does not go through here and must not be "simplified" into
/// it: [GlassSheetScrollPhysics] is installed on descendant scrollables
/// directly, through a `ScrollConfiguration`, which reaches them without
/// anything having to look anything up. This scope exists for the things a
/// lookup is the only answer to — a row deep in the content that drives its
/// own `GlassPresence` from the sheet's height, or a button in the content
/// that calls [GlassDetentSheetController.animateToDetent] on the sheet it is
/// sitting in.
class GlassDetentSheetScope extends InheritedWidget {
  /// Creates a scope.
  const GlassDetentSheetScope({
    required this.controller,
    required super.child,
    super.key,
  });

  /// The sheet's controller.
  final GlassDetentSheetController controller;

  /// The nearest enclosing sheet's controller, or null outside one.
  ///
  /// Nullable rather than asserting: a widget that is written to work both
  /// inside a sheet and on a page of its own is the ordinary case, and the
  /// answer "there is no sheet" is one it can act on.
  static GlassDetentSheetController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<GlassDetentSheetScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(GlassDetentSheetScope oldWidget) =>
      !identical(oldWidget.controller, controller);
}

/// The grab indicator.
///
/// Drawn, not a `Glass` of its own: a capsule of glass on a sheet of glass is
/// a second refraction over the first, which is the stacked filter this
/// package exists to avoid. `GlassHostScope` is the general form of this rule.
class _Handle extends StatelessWidget {
  const _Handle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            // Apple's own indicator is a low-contrast fill, not the label
            // colour at full strength: it is an affordance, not content.
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }
}
