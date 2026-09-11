import 'package:flutter/material.dart';
import 'package:glass_forge/glass_forge.dart';

/// The shapes the specimen screen lets you pick between.
enum ShowcaseShape { roundedRectangle, oval, superellipse }

/// Display strings and geometry for [ShowcaseShape].
extension ShowcaseShapeX on ShowcaseShape {
  static const _cornerRadius = BorderRadius.all(Radius.circular(28));

  /// The label shown on the shape segmented control.
  String get label => switch (this) {
    ShowcaseShape.roundedRectangle => 'Rounded rect',
    ShowcaseShape.oval => 'Oval',
    ShowcaseShape.superellipse => 'Superellipse',
  };

  /// The `GlassShape` this option renders as.
  GlassShape toGlassShape() => switch (this) {
    ShowcaseShape.roundedRectangle => const GlassRoundedRectangle(
      radius: _cornerRadius,
    ),
    ShowcaseShape.oval => const GlassOval(),
    ShowcaseShape.superellipse => const GlassSuperellipse(
      radius: _cornerRadius,
    ),
  };
}
