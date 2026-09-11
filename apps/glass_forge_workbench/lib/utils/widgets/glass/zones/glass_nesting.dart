import 'package:flutter/widgets.dart';

/// Marks a subtree as drawn on top of kit glass.
///
/// A kit layer inside another would push one backdrop filter inside
/// another's subtree, which washes out white on physical iPhones. So a kit
/// layer that finds this marker above it paints an inset surface instead of
/// opening a pass — a button on a glass sheet still looks like glass, and the
/// sheet stays the only filter under it.
class GlassNesting extends InheritedWidget {
  const GlassNesting({required super.child, super.key});

  static bool isInside(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassNesting>() != null;

  @override
  bool updateShouldNotify(GlassNesting oldWidget) => false;
}
