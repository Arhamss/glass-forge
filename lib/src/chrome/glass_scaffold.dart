import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/chrome/glass_handoff.dart';
import 'package:glass_forge/src/design/glass_text.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';
import 'package:glass_forge/src/widgets/glass_presence.dart';

/// The composition rules every glass screen obeys, made the default.
///
/// What glass refracts is painted **behind** the layer that draws it, never
/// inside it. The scaffold owns two layers: one for [body], and one above
/// it that carries only [topBar] and [bottomBar]. [background] and [body]
/// paint under the bars' layer, so the bars refract them. Getting that
/// arrangement right by hand is easy to get backwards once a screen has
/// more than one bar; this widget makes it the only arrangement there is.
///
/// Glass inside [body] (a `GlassSwitch` in a settings list, a
/// `GlassButton`) all shares the body's one layer rather than each control
/// building an implicit layer of its own. That layer only draws glass in
/// the band between the bars: a body control scrolled under a bar is cut
/// off at the bar's edge rather than rendered as a second backdrop filter
/// beneath the bar's (flutter#187820). The body's plain content is not
/// clipped, and keeps scrolling under the bars for them to refract.
///
/// Both bars carry their own safe-area inset, and [body] is handed that
/// same space back through `MediaQuery.padding` — the way Material's
/// `Scaffold` hands a `ListView` room to avoid its app bar — so a
/// scrollable in [body] clears the bars on its own, while [body] itself
/// still spans the full screen and keeps painting (and scrolling) under
/// them for the bars to refract.
///
/// [bottomBar] also rides `MediaQuery.viewInsets`' bottom inset, so it lifts
/// clear of the keyboard rather than being covered by it. The body then
/// reads the keyboard once, as part of the bar's height in
/// `MediaQuery.padding.bottom`, and sees a `viewInsets.bottom` of zero. A
/// `GlassTextField` in the body scrolls itself clear of both the keyboard
/// and the bar riding it.
///
/// Each bar's glass fades through its own [GlassPresence], driven by the
/// inverse of `ModalRoute.of(context)?.secondaryAnimation`: full presence
/// while nothing covers the page, reaching none in the first 40% of a
/// covering route's arrival. That is the handoff `showGlassSheet` needs —
/// the chrome beneath a sheet must reach presence 0 before the sheet's own
/// glass rises, or the two are a stacked backdrop filter over the same
/// pixels.
///
/// Like Material's `Scaffold` and `CupertinoPageScaffold`, it gives the
/// page a text style of its own — iOS's 17-point body in the theme's label
/// colour, undecorated — rather than leaving text to `WidgetsApp`'s
/// debug fallback when no Material is above it. Put a [DefaultTextStyle]
/// inside [body] for type of your own.
///
/// Both bars fade for any covering route, a short sheet included, though
/// such a sheet only covers the bottom of the screen. That is deliberate:
/// a sheet's height is its content's and can grow to the top safe area,
/// and nothing tells the page beneath how far up a covering route reaches,
/// so fading only the bottom bar would leave a tall sheet's glass over a
/// top bar's.
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
  /// Spans the full screen behind the bars' layer, so it keeps painting —
  /// and scrolling — under [topBar] and [bottomBar] for them to refract.
  /// Use [MediaQuery.paddingOf] (most scrollables already do,
  /// automatically) to keep the content itself clear of the bars.
  ///
  /// Glass in here renders in the body's own layer, and only between the
  /// bars; see the class doc.
  final Widget body;

  /// What sits behind [body], in the same full-screen stacking position.
  ///
  /// Null paints nothing there, so whatever is behind this whole widget
  /// shows through — right for a scaffold dropped over an existing
  /// backdrop.
  final Widget? background;

  /// Glass pinned to the top edge, in the bars' [GlassLayer].
  final Widget? topBar;

  /// Glass pinned to the bottom edge, inside the same layer.
  final Widget? bottomBar;

  /// The material glass in either layer inherits: [GlassLayer.material]
  /// for the body's layer and the bars'. Null takes [GlassLayer]'s own
  /// default.
  ///
  /// Not a surface override, as `GlassSurface.material` and
  /// `GlassTabBar.selectionMaterial` are: most glass here names its own
  /// material (every `GlassSurface` resolves its role's, every control the
  /// control role's), and only a bare `Glass` with no material of its own
  /// reads this one.
  final GlassMaterial? material;

  @override
  Widget build(BuildContext context) {
    // A real text style for the whole page, bars included: nothing above
    // a glass page is guaranteed to have set one, and without it text
    // draws in `WidgetsApp`'s underlined debug fallback.
    return GlassTextDefaults(
      child: _GlassScaffoldBody(
        background: background,
        body: body,
        topBar: topBar,
        bottomBar: bottomBar,
        material: material,
      ),
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

  /// Stateless, so one instance serves every scaffold.
  static final _ScaffoldLayout _layout = _ScaffoldLayout();

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

  /// One bar's own layer, its glass clipped to the layer's exact bounds and
  /// fading through the scaffold's presence.
  Widget _barLayer(GlassMaterial material, Widget bar) {
    return GlassLayerClip.toBounds(
      child: GlassLayer(
        material: material,
        child: GlassPresence(presence: _presence, child: bar),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topBar = widget.topBar;
    final bottomBar = widget.bottomBar;
    final material = widget.material ?? const GlassMaterial();

    return CustomMultiChildLayout(
      delegate: _layout,
      children: [
        if (widget.background != null)
          LayoutId(id: _Slot.background, child: widget.background!),
        // Built during layout, once both bars have been measured: the
        // body's padding and its glass band come from the bars' heights in
        // the same frame, the first one included, rather than a frame late.
        LayoutId(
          id: _Slot.body,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bars = constraints is _BodyConstraints ? constraints : null;
              return _buildBody(
                media: media,
                material: material,
                height: constraints.maxHeight,
                topBarHeight: bars?.topBarHeight ?? 0,
                bottomBarHeight: bars?.bottomBarHeight ?? 0,
              );
            },
          ),
        ),
        // Each bar in a layer of its own, the size of the bar, whose
        // passes are clipped to exactly that: a bar's filter never reaches
        // over the body's band, where body glass draws. One layer for both
        // bars would be one pass whose clip spans the screen between them,
        // over every piece of body glass.
        if (topBar != null)
          LayoutId(
            id: _Slot.topBar,
            child: _barLayer(
              material,
              SafeArea(
                bottom: false,
                left: false,
                right: false,
                child: topBar,
              ),
            ),
          ),
        if (bottomBar != null)
          LayoutId(
            id: _Slot.bottomBar,
            child: _barLayer(
              material,
              // Rides the keyboard: as `viewInsets.bottom` grows this bar
              // lifts by the same amount, clear of it, rather than being
              // covered the way a bar fixed to the screen's edge would be.
              Padding(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  child: bottomBar,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The body, in its own layer, given the bars' measured heights.
  Widget _buildBody({
    required MediaQueryData media,
    required GlassMaterial material,
    required double height,
    required double topBarHeight,
    required double bottomBarHeight,
  }) {
    final hasTop = widget.topBar != null;
    final hasBottom = widget.bottomBar != null;
    // The body's own copy of `MediaQuery`, telling it how much of the top
    // and bottom a bar is covering — exactly what Material's `Scaffold`
    // does for a `ListView` under its app bar. A bar's measured height
    // already includes the safe-area inset the `SafeArea` around it adds,
    // so this replaces the ambient inset rather than adding to it; with no
    // bar the ambient safe-area inset is left alone, so content still
    // clears a notch with nothing here to clear it for.
    //
    // A bottom bar rides the keyboard, so its measured height already
    // counts the keyboard. The body's `viewInsets.bottom` goes to zero with
    // it, or a descendant that pads by both would count the keyboard twice
    // — the same trade Material's `Scaffold` makes when it takes the inset
    // out of its body.
    final body = MediaQuery(
      data: media.copyWith(
        padding: EdgeInsets.only(
          left: media.padding.left,
          right: media.padding.right,
          top: hasTop ? topBarHeight : media.padding.top,
          bottom: hasBottom ? bottomBarHeight : media.padding.bottom,
        ),
        viewInsets: hasBottom
            ? media.viewInsets.copyWith(bottom: 0)
            : media.viewInsets,
      ),
      child: widget.body,
    );

    // The body's own layer, for any glass inside it — a switch in a
    // settings list — so that glass shares one layer instead of each
    // control building an implicit one. Its passes are clipped to the band
    // between the bars: body glass scrolled under a bar is cut away there,
    // never a second backdrop filter under the bar's. The body's content
    // itself is not clipped and keeps painting under the bars for them to
    // refract.
    return GlassLayerClip(
      rect: Rect.fromLTRB(
        Rect.largest.left,
        hasTop ? topBarHeight : Rect.largest.top,
        Rect.largest.right,
        hasBottom ? height - bottomBarHeight : Rect.largest.bottom,
      ),
      child: GlassLayer(material: material, child: body),
    );
  }
}

enum _Slot { background, body, topBar, bottomBar }

/// The constraints the body is laid out with: tight to the scaffold, and
/// carrying the heights of the bars laid out just before it.
///
/// How the heights reach the body's `LayoutBuilder` within the same layout
/// pass — the way Material's `Scaffold` hands its body the app bar's
/// height. Equality counts the heights, so a bar that changes height
/// rebuilds the body, and one that does not rebuilds nothing.
class _BodyConstraints extends BoxConstraints {
  _BodyConstraints.tight(
    super.size, {
    required this.topBarHeight,
    required this.bottomBarHeight,
  }) : super.tight();

  final double topBarHeight;
  final double bottomBarHeight;

  @override
  bool operator ==(Object other) {
    return super == other &&
        other is _BodyConstraints &&
        other.topBarHeight == topBarHeight &&
        other.bottomBarHeight == bottomBarHeight;
  }

  @override
  int get hashCode =>
      Object.hash(super.hashCode, topBarHeight, bottomBarHeight);
}

/// Lays the bars out first, at their own heights, then the body and the
/// background across the whole scaffold.
class _ScaffoldLayout extends MultiChildLayoutDelegate {
  _ScaffoldLayout();

  @override
  void performLayout(Size size) {
    final loose = BoxConstraints.loose(size);
    var topBarHeight = 0.0;
    var bottomBarHeight = 0.0;
    if (hasChild(_Slot.topBar)) {
      final bar = layoutChild(_Slot.topBar, loose);
      topBarHeight = bar.height;
      positionChild(_Slot.topBar, Offset((size.width - bar.width) / 2, 0));
    }
    if (hasChild(_Slot.bottomBar)) {
      final bar = layoutChild(_Slot.bottomBar, loose);
      bottomBarHeight = bar.height;
      positionChild(
        _Slot.bottomBar,
        Offset((size.width - bar.width) / 2, size.height - bar.height),
      );
    }
    layoutChild(
      _Slot.body,
      _BodyConstraints.tight(
        size,
        topBarHeight: topBarHeight,
        bottomBarHeight: bottomBarHeight,
      ),
    );
    positionChild(_Slot.body, Offset.zero);
    if (hasChild(_Slot.background)) {
      layoutChild(_Slot.background, BoxConstraints.tight(size));
      positionChild(_Slot.background, Offset.zero);
    }
  }

  @override
  bool shouldRelayout(_ScaffoldLayout oldDelegate) => false;
}
