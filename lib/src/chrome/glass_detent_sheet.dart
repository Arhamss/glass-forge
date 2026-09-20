import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/chrome/detent_geometry.dart';
import 'package:glass_forge/src/chrome/glass_detent.dart';
import 'package:glass_forge/src/chrome/glass_detent_sheet_controller.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/design/glass_tokens.dart';
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
    this.gap = 12,
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
  final ValueChanged<int>? onDetentChanged;

  /// Drives the sheet from outside. Created internally when null, and only
  /// disposed when created internally.
  final GlassDetentSheetController? controller;

  /// What is behind the sheet, where the app knows — see `GlassSurface`.
  final Color? backdrop;

  /// How far the floating sheet is inset from the screen's edges.
  final double gap;

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

class _GlassDetentSheetState extends State<GlassDetentSheet>
    with SingleTickerProviderStateMixin {
  GlassDetentSheetController? _internal;
  GlassDetentSheetController get _controller =>
      widget.controller ?? (_internal ??= _createController());

  List<double> _resolved = const <double>[];

  GlassDetentSheetController _createController() =>
      GlassDetentSheetController(vsync: this);

  @override
  void initState() {
    super.initState();
    _controller.onDetentChanged = _onDetentChanged;
  }

  @override
  void didUpdateWidget(GlassDetentSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller?.onDetentChanged = null;
    if (widget.controller != null && _internal != null) {
      // The sheet made one before the caller supplied theirs. Nothing can
      // reach it now and its ticker would go on being driven, so it is
      // retired here rather than at [dispose] — it is still a controller
      // this state created, which is the only test [dispose] applies.
      _internal!.dispose();
      _internal = null;
    }
    _controller.onDetentChanged = _onDetentChanged;
    if (_resolved.isNotEmpty) {
      // A controller handed over mid-life has never been told this sheet's
      // detents, and [_syncDetents] will not tell it: that only speaks up
      // when the resolved heights change, and swapping the controller does
      // not change them. Without this the sheet would drive a controller
      // that believes it has nowhere to rest.
      _controller.setDetents(_resolved);
    }
  }

  void _onDetentChanged(int index) => widget.onDetentChanged?.call(index);

  @override
  void dispose() {
    // Only the one this state made. A caller's controller outlives the widget
    // by construction — that is what passing one in is for.
    _internal?.dispose();
    widget.controller?.onDetentChanged = null;
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
        _syncDetents(available);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final metrics = GlassDetentSheetMetrics.at(
              height: _controller.value,
              lowest: _controller.lowest,
              top: _controller.top,
              gap: widget.gap,
              floatingRadius: floatingRadius,
              flushRadius: widget.flushRadius,
            );
            return Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: metrics.gap,
                  right: metrics.gap,
                  bottom: metrics.gap,
                ),
                child: SizedBox(
                  height: metrics.height,
                  child: _buildSheet(context, metrics, padding),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheet(
    BuildContext context,
    GlassDetentSheetMetrics metrics,
    EdgeInsets padding,
  ) {
    // The role's style, but not the role's shape: the radius morphs
    // continuously, and the ladder has steps. Everything else — material,
    // shadows, the vibrant label colour — comes from the role as it should.
    final style = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.sheet,
      size: Size(
        MediaQuery.sizeOf(context).width - metrics.gap * 2,
        metrics.height,
      ),
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
        material: style.material,
        // The drag detector sits *inside* the glass, not around it. Both
        // cover the same box, so the gesture behaves identically either
        // way, but only this order puts the surface itself on the hit-test
        // path: a `Glass` whose children all decline a hit adds nothing of
        // its own, and a sheet no hit test ever names is one no test — and
        // no future gesture that wants to ask what it landed on — can find.
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
                        // The gap already clears the home indicator while the
                        // sheet floats. Once it is flush the inset is the
                        // sheet's own to carry.
                        padding: EdgeInsets.only(
                          bottom: metrics.gap > 0 ? 0 : padding.bottom,
                        ),
                        child: widget.child,
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
