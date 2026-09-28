import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/chrome/glass_handoff.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';
import 'package:glass_forge/src/widgets/glass_presence.dart';

/// The composition rules every glass screen obeys, made the default.
///
/// What glass refracts is painted **behind** the one [GlassLayer] a screen
/// owns, never inside it: [background] and [body] sit under the layer,
/// [topBar] and [bottomBar] are the only glass inside it. Getting that
/// arrangement right by hand is easy to get backwards once a screen has
/// more than one bar; this widget makes it the only arrangement there is.
///
/// Both bars carry their own safe-area inset, and [body] is handed that
/// same space back through `MediaQuery.padding` — the way Material's
/// `Scaffold` hands a `ListView` room to avoid its app bar — so a
/// scrollable in [body] clears the bars on its own, while [body] itself
/// still spans the full screen and keeps painting (and scrolling) under
/// them for the bars to refract.
///
/// [bottomBar] also rides `MediaQuery.viewInsets`' bottom inset, so it lifts
/// clear of the keyboard rather than being covered by it.
///
/// Each bar's glass fades through its own [GlassPresence], driven by the
/// inverse of `ModalRoute.of(context)?.secondaryAnimation`: full presence
/// while nothing covers the page, reaching none in the first 40% of a
/// covering route's arrival. That is the handoff `showGlassSheet` needs —
/// the chrome beneath a sheet must reach presence 0 before the sheet's own
/// glass rises, or the two are a stacked backdrop filter over the same
/// pixels.
///
/// ```dart
/// GlassScaffold(
///   background: const ColoredBox(color: Color(0xFF101820)),
///   topBar: GlassSurface.navigationBar(child: YourTitle()),
///   body: ListView(children: rows),
/// )
/// ```
class GlassScaffold extends StatelessWidget {
  /// Creates a scaffold.
  const GlassScaffold({
    required this.body,
    this.background,
    this.topBar,
    this.bottomBar,
    this.material,
    super.key,
  });

  /// The screen's content.
  ///
  /// Spans the full screen behind the layer, so it keeps painting — and
  /// scrolling — under [topBar] and [bottomBar] for them to refract. Use
  /// [MediaQuery.paddingOf] (most scrollables already do, automatically) to
  /// keep the content itself clear of the bars.
  final Widget body;

  /// What sits behind [body], in the same full-screen stacking position.
  ///
  /// Null paints nothing there, so whatever is behind this whole widget
  /// shows through — right for a scaffold dropped over an existing
  /// backdrop.
  final Widget? background;

  /// Glass pinned to the top edge, inside this widget's one [GlassLayer].
  final Widget? topBar;

  /// Glass pinned to the bottom edge, inside the same layer.
  final Widget? bottomBar;

  /// The layer's material. Null takes [GlassLayer]'s own default.
  final GlassMaterial? material;

  @override
  Widget build(BuildContext context) {
    return _GlassScaffoldBody(
      background: background,
      body: body,
      topBar: topBar,
      bottomBar: bottomBar,
      material: material,
    );
  }
}

class _GlassScaffoldBody extends StatefulWidget {
  const _GlassScaffoldBody({
    required this.body,
    required this.background,
    required this.topBar,
    required this.bottomBar,
    required this.material,
  });

  final Widget body;
  final Widget? background;
  final Widget? topBar;
  final Widget? bottomBar;
  final GlassMaterial? material;

  @override
  State<_GlassScaffoldBody> createState() => _GlassScaffoldBodyState();
}

class _GlassScaffoldBodyState extends State<_GlassScaffoldBody> {
  /// The route this state last read [_presence] from.
  ///
  /// Compared by identity so a dependency change that is not a route change
  /// — a `MediaQuery` update from a keyboard opening, say — never rebuilds
  /// [_presence]. `GlassPresence` holds its animation by identity: a fresh
  /// one every build would be a fresh backdrop pass every build.
  ModalRoute<Object?>? _route;

  Animation<double> _presence = const AlwaysStoppedAnimation<double>(1);

  double _topBarHeight = 0;
  double _bottomBarHeight = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) {
      return;
    }
    _route = route;
    final secondary = route?.secondaryAnimation;
    // No route at all — this scaffold was not reached through a
    // `Navigator` push — means nothing can ever cover it, so it stays at
    // full presence for its whole life rather than tracking an animation
    // that will never move.
    //
    // Otherwise the bars are gone within the first part of the covering
    // route's animation rather than across all of it, so that a covering
    // glass surface (`showGlassSheet`'s, riding the rest) never renders
    // while they still do. `secondaryAnimation` is the covering route's own
    // animation, handed over by `Navigator`, and nothing on that route can
    // reshape it — so the reshaping happens here. `drive` rather than a
    // `CurvedAnimation`: it registers nothing on `secondary` until someone
    // listens, so there is nothing to dispose when the route changes.
    _presence = secondary == null
        ? const AlwaysStoppedAnimation<double>(1)
        : secondary.drive(
            Tween<double>(
              begin: 1,
              end: 0,
            ).chain(CurveTween(curve: coveredChromeInterval)),
          );
  }

  void _handleTopBarSize(Size size) {
    if (mounted && size.height != _topBarHeight) {
      setState(() => _topBarHeight = size.height);
    }
  }

  void _handleBottomBarSize(Size size) {
    if (mounted && size.height != _bottomBarHeight) {
      setState(() => _bottomBarHeight = size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topBar = widget.topBar;
    final bottomBar = widget.bottomBar;

    // The body's own copy of `MediaQuery`, telling it how much of the top
    // and bottom a bar is covering — exactly what Material's `Scaffold`
    // does for a `ListView` under its app bar. A bar's measured height
    // already includes the safe-area inset the `SafeArea` below adds
    // around it, so this replaces the ambient inset rather than adding to
    // it; with no bar the ambient safe-area inset is left alone, so content
    // still clears a notch with nothing here to clear it for.
    final body = MediaQuery(
      data: media.copyWith(
        padding: EdgeInsets.only(
          left: media.padding.left,
          right: media.padding.right,
          top: topBar == null ? media.padding.top : _topBarHeight,
          bottom: bottomBar == null ? media.padding.bottom : _bottomBarHeight,
        ),
      ),
      child: widget.body,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.background != null) widget.background!,
        body,
        // The screen's one `GlassLayer`. Its own `Stack` below only ever
        // carries the bars — glass, and the only glass this widget builds.
        GlassLayer(
          material: widget.material ?? const GlassMaterial(),
          child: Stack(
            children: [
              if (topBar != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: GlassPresence(
                    presence: _presence,
                    child: _MeasureSize(
                      onChange: _handleTopBarSize,
                      child: SafeArea(
                        bottom: false,
                        left: false,
                        right: false,
                        child: topBar,
                      ),
                    ),
                  ),
                ),
              if (bottomBar != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: GlassPresence(
                    presence: _presence,
                    child: _MeasureSize(
                      onChange: _handleBottomBarSize,
                      // Rides the keyboard: as `viewInsets.bottom` grows
                      // this bar lifts by the same amount, clear of it,
                      // rather than being covered the way a bar fixed to
                      // the screen's edge would be.
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: media.viewInsets.bottom,
                        ),
                        child: SafeArea(
                          top: false,
                          left: false,
                          right: false,
                          child: bottomBar,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Reports [child]'s laid-out size to [onChange] after every layout that
/// changes it.
///
/// Deferred to the end of the frame rather than called from
/// [RenderObject.performLayout] directly: layout is still in progress at
/// that point, and triggering a rebuild (which a bar's measured height
/// eventually does, through [State.setState]) from inside someone else's
/// layout throws. A frame late is invisible here — a bar's size settles
/// long before its own entrance animation does, if it animates at all — and
/// the callback runs only when the size actually changed, so a settled
/// layout schedules nothing.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required Widget super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasureSize(onChange);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMeasureSize).onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;

  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = size;
    if (_reported == newSize) {
      return;
    }
    _reported = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(newSize));
  }
}
