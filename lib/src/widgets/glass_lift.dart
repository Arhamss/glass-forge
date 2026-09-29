import 'package:flutter/widgets.dart';

/// Carries a "lift" animation down to the glass it brightens: 0 is the
/// material as declared, 1 is its lit version (see
/// `GlassComposition.liftedHighlight` and
/// `GlassComposition.liftedTintOpacity`).
///
/// Presence's twin, and driven the same way. The layer keys a shape's pass
/// by the animation's identity and reads its value as a uniform, so an
/// animating lift costs a rebuilt image filter per frame and never a new
/// pass, a re-sort of the layer's shapes or a rebaked matte. A material
/// animated by value instead is a new pass key on every frame.
///
/// Internal: `GlassTextField` lights its glass with it on focus.
class GlassLiftScope extends InheritedWidget {
  /// Creates a scope.
  const GlassLiftScope({
    required this.lift,
    required super.child,
    super.key,
  });

  /// What lifts the glass below this point, 0 to 1, or null for nothing.
  ///
  /// Null is what lets a caller keep this scope in its tree at rest, so
  /// the glass under it is not remounted when a lift starts, while still
  /// sharing a pass with its unlifted neighbours.
  final Animation<double>? lift;

  /// The nearest enclosing lift, if any.
  static Animation<double>? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassLiftScope>()?.lift;
  }

  @override
  bool updateShouldNotify(GlassLiftScope oldWidget) =>
      !identical(oldWidget.lift, lift);
}
