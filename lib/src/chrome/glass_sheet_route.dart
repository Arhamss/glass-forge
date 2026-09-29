import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/chrome/glass_handoff.dart';
import 'package:glass_forge/src/chrome/glass_sheet_handle.dart';
import 'package:glass_forge/src/design/glass_chrome_colors.dart';
import 'package:glass_forge/src/design/glass_surface.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_text.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';
import 'package:glass_forge/src/widgets/glass_presence.dart';

/// Presents [builder]'s content on a modal glass sheet rising from the
/// bottom edge, and completes with the value the sheet is popped with.
///
/// The sheet is a `GlassSurface.sheet` that materializes through
/// [GlassPresence] as the route animates, over a painted scrim that dims the
/// page beneath — paint, not glass, so the sheet stays the only glass over
/// that region and refracts the dimmed page.
///
/// Presenting is a handoff, not a cross-fade. Glass chrome on the page
/// beneath — a `GlassScaffold`'s bars — reaches presence 0 in the first 40%
/// of the route's animation, and only then does the sheet's glass rise from
/// 0, so the two are never both a backdrop filter over the same pixels
/// (flutter#187820), however faint either one is. Dismissing runs the same
/// handoff backwards.
///
/// When [isDismissible] is true, a tap on the scrim, a drag down past half
/// the sheet's height, or a downward fling dismisses it with a null result.
/// When false, only a `Navigator.pop` from inside the sheet does. Reduce
/// Motion presents and dismisses instantly.
///
/// [material] replaces the sheet role's material, as
/// `GlassSurface.material` does; null keeps the role's. The scrim and the
/// handle take their colours from the theme's `GlassTokens.chrome`.
///
/// [barrierLabel] is what a screen reader reads for the scrim. It is
/// English by default: this package has no localizations of its own, so
/// pass a translated label from an app that has them.
///
/// [useRootNavigator] pushes onto the outermost `Navigator` rather than
/// the nearest — for a sheet that must cover a tab scaffold's nested
/// navigator, bars and all. [routeSettings] names the route, as for any
/// other push.
///
/// The sheet rises clear of the keyboard: with the keyboard up, its bottom
/// edge sits above it, so a `GlassTextField` in the sheet stays in view.
///
/// The page beneath follows the handoff only when its route lets this one
/// drive its `secondaryAnimation`: any `PageRoute` does, including
/// `MaterialPageRoute`, `CupertinoPageRoute` and `PageRouteBuilder`, as long
/// as its result type accepts `T` — a `MaterialPageRoute<int>` beneath a
/// `showGlassSheet<String>` does not, and there `Navigator` keeps the chrome
/// at full presence.
///
/// ```dart
/// final picked = await showGlassSheet<String>(
///   context: context,
///   builder: (context) => GlassButton(
///     onPressed: () => Navigator.of(context).pop('done'),
///     child: const Text('Done'),
///   ),
/// );
/// ```
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  GlassMaterial? material,
  String barrierLabel = 'Dismiss',
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
}) {
  final theme = GlassTheme.of(context);
  final duration = theme.motion
      .of(theme.surfaces.of(GlassSurfaceRole.sheet).motion)
      .duration;
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    _GlassSheetRoute<T>(
      builder: builder,
      isDismissible: isDismissible,
      duration: duration,
      material: material,
      scrimLabel: barrierLabel,
      chrome: theme.tokens.chrome,
      settings: routeSettings,
    ),
  );
}

/// The space between the sheet and the screen's edges.
const double _sheetMargin = 8;

/// A fling faster than this, in logical pixels per second downward,
/// dismisses however little the sheet has been dragged.
const double _flingVelocity = 700;

/// The sheet's rise, in the route's own animation: nothing before the
/// handoff, then a decelerating slide in for the rest.
const Curve _riseCurve = Curves.easeOutCubic;

// A `PageRoute`, not a `PopupRoute`, for one reason: `Navigator` only lets a
// covering route drive the covered route's `secondaryAnimation` when the
// covered route agrees, and a plain `PageRoute` (the one `WidgetsApp` and
// `PageRouteBuilder` build) agrees only for another `PageRoute`. Material and
// Cupertino page routes agree for anything with a `delegatedTransition`,
// which this route also has. Without that agreement the covered chrome never
// hears about the sheet and stays at full presence under it.
class _GlassSheetRoute<T> extends PageRoute<T> {
  _GlassSheetRoute({
    required this.builder,
    required this.isDismissible,
    required this.duration,
    required this.material,
    required this.scrimLabel,
    required this.chrome,
    super.settings,
  });

  final WidgetBuilder builder;
  final bool isDismissible;
  final Duration duration;
  final GlassMaterial? material;
  final String scrimLabel;

  /// The theme's chrome colours when the sheet was shown.
  final GlassChromeColors chrome;

  /// The sheet's rise through the second part of [animation]: position and
  /// glass both ride it.
  late final Animation<double> _rise;

  /// [_rise], also handed off when something covers this sheet in turn —
  /// another sheet, say — so it is never glass under glass itself.
  ///
  /// Built once in [install] and held: [GlassPresence] holds its animation
  /// by identity.
  late final Animation<double> _presence;

  @override
  void install() {
    super.install();
    _rise = animation!
        .drive(CurveTween(curve: coveringGlassInterval))
        .drive(CurveTween(curve: _riseCurve));
    final uncovered = secondaryAnimation!.drive(
      Tween<double>(
        begin: 1,
        end: 0,
      ).chain(CurveTween(curve: coveredChromeInterval)),
    );
    _presence = AnimationMin<double>(_rise, uncovered);
    GlassReduceMotion.instance.addListener(_onReduceMotion);
  }

  @override
  void dispose() {
    GlassReduceMotion.instance.removeListener(_onReduceMotion);
    super.dispose();
  }

  /// Reduce Motion turned on while the sheet is still rising or falling
  /// lands it now, rather than letting the rest of the animation play.
  void _onReduceMotion() {
    final controller = this.controller;
    if (!GlassReduceMotion.instance.value ||
        controller == null ||
        !controller.isAnimating) {
      return;
    }
    controller.value = controller.status == AnimationStatus.reverse ? 0 : 1;
  }

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  bool get barrierDismissible => isDismissible;

  @override
  Color get barrierColor => chrome.scrim;

  @override
  String get barrierLabel => scrimLabel;

  @override
  Duration get transitionDuration =>
      GlassReduceMotion.instance.value ? Duration.zero : duration;

  // Keeps the covered page still. Given a delegated transition, a Material or
  // Cupertino page route beneath hands its outgoing transition to this
  // instead of sliding or zooming away — and a sheet leaves the page where
  // it is.
  @override
  DelegatedTransitionBuilder? get delegatedTransition => _keepPageStill;

  static Widget? _keepPageStill(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) => child;

  @override
  bool didPop(T? result) {
    // `transitionDuration` is read once, when the route is installed. Reduce
    // Motion switched on while the sheet was up must still take it down
    // instantly.
    if (GlassReduceMotion.instance.value) {
      controller?.reverseDuration = Duration.zero;
    }
    return super.didPop(result);
  }

  /// Moves the sheet by [dy] logical pixels under a finger, out of a total
  /// [travel] between fully in and fully out.
  void _drag(double dy, double travel) {
    final controller = this.controller;
    // Not while popping: the finger must not fight the dismissal.
    if (controller == null || !isDismissible || !isCurrent || travel <= 0) {
      return;
    }
    // In the rise's own, curved space, so the sheet tracks the finger one to
    // one rather than lagging it where the curve is flat.
    final rise = (_rise.value - dy / travel).clamp(0.0, 1.0);
    controller.value =
        glassHandoffPoint + _uncurve(rise) * (1 - glassHandoffPoint);
  }

  void _dragEnd(double velocity) {
    final controller = this.controller;
    if (controller == null || !isDismissible || !isCurrent) {
      return;
    }
    if (velocity > _flingVelocity || _rise.value < 0.5) {
      navigator?.pop();
    } else {
      controller.forward();
    }
  }

  /// The inverse of [_riseCurve].
  static double _uncurve(double rise) =>
      1 - math.pow(1 - rise, 1 / 3).toDouble();

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _GlassSheetPage(route: this);
  }
}

class _GlassSheetPage extends StatelessWidget {
  const _GlassSheetPage({required this.route});

  final _GlassSheetRoute<Object?> route;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    // The keyboard covers the bottom safe area too, so the sheet clears
    // whichever reaches higher.
    final bottom = math.max(
      padding.bottom,
      MediaQuery.viewInsetsOf(context).bottom,
    );
    // The sheet's own layer. It is a separate overlay entry above the page,
    // so the page's layer cannot hold it; its backdrop pass reads whatever
    // is painted beneath it in the scene — the page, dimmed by the scrim
    // `ModalRoute` paints in the entry just below this one.
    return GlassLayer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedBuilder(
          animation: route._rise,
          builder: (context, child) => FractionalTranslation(
            translation: Offset(0, 1 - route._rise.value),
            child: child,
          ),
          child: Builder(
            builder: (boxContext) => Padding(
              padding: EdgeInsets.fromLTRB(
                _sheetMargin + padding.left,
                _sheetMargin + padding.top,
                _sheetMargin + padding.right,
                _sheetMargin + bottom,
              ),
              child: GestureDetector(
                onVerticalDragUpdate: (details) => route._drag(
                  details.primaryDelta ?? 0,
                  boxContext.size?.height ?? 0,
                ),
                onVerticalDragEnd: (details) =>
                    route._dragEnd(details.primaryVelocity ?? 0),
                child: _GlassSheet(route: route),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.route});

  final _GlassSheetRoute<Object?> route;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: GlassPresence(
        presence: route._presence,
        // The surface fades its content with this presence. The text style
        // is the page's: a route's content has no other above it, and the
        // surface sets its own label colour on it.
        child: GlassTextDefaults(
          child: GlassSurface.sheet(
            material: route.material,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              removeLeft: true,
              removeRight: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (route.isDismissible)
                    Builder(
                      // The surface sets its label colour on the ambient
                      // text style; the role's own is a fallback that the
                      // surface above always makes unreachable.
                      builder: (context) => GlassSheetHandle(
                        color:
                            route.chrome.handle ??
                            DefaultTextStyle.of(context).style.color ??
                            GlassTheme.surfaceOf(
                              context,
                              GlassSurfaceRole.sheet,
                              size: MediaQuery.sizeOf(context),
                            ).labelColor,
                      ),
                    ),
                  Flexible(child: Builder(builder: route.builder)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
