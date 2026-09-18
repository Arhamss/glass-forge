import 'package:flutter/widgets.dart';

/// Marks a subtree as being drawn *on* a glass surface.
///
/// This is how one control class is correct in both places it can be put,
/// with no mode for a developer to remember. A switch on a page's content
/// makes its knob glass; the same switch in a glass toolbar paints its knob
/// instead, because a second refraction over the first is a stacked backdrop
/// filter — flutter#187820, the bug this package is built around.
///
/// ```dart
/// final onGlass = GlassHostScope.isOnGlass(context);
/// return onGlass ? _painted() : Glass(shape: shape, child: _painted());
/// ```
class GlassHostScope extends InheritedWidget {
  /// Creates a scope.
  const GlassHostScope({required super.child, super.key});

  /// The nearest enclosing glass surface's scope, if any.
  ///
  /// This walks to the nearest ancestor `Glass`, not only an immediate
  /// parent — a control several widgets deep inside a `Glass`'s child is
  /// still on glass.
  static GlassHostScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassHostScope>();
  }

  /// Whether [context] is drawn on a glass surface.
  static bool isOnGlass(BuildContext context) => maybeOf(context) != null;

  @override
  bool updateShouldNotify(GlassHostScope oldWidget) => false;
}
