import 'dart:math' as math;

import 'package:glass_forge_workbench/exports.dart';

/// Puts the menu under the finger, start-aligned, flipping above it when
/// there is no room below, and never closer than a margin to the safe area.
class GlassContextMenuLayout extends SingleChildLayoutDelegate {
  const GlassContextMenuLayout({
    required this.anchor,
    required this.padding,
    required this.textDirection,
  });

  final Offset anchor;
  final EdgeInsets padding;
  final TextDirection textDirection;

  static const double _margin = AppSpacing.s12;

  // Keeps the menu's edge off the fingertip, so the first row is not
  // hidden under it.
  static const double _gap = AppSpacing.s8;

  /// The menu's width wherever the screen allows it.
  static const double menuWidth = 240;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final safe = padding.deflateSize(constraints.biggest);
    final width = math.min(
      menuWidth,
      math.max<double>(0, safe.width - _margin * 2),
    );
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max<double>(0, safe.height - _margin * 2),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minX = padding.left + _margin;
    final maxX = math.max(
      minX,
      size.width - padding.right - _margin - childSize.width,
    );
    final minY = padding.top + _margin;
    final maxY = math.max(
      minY,
      size.height - padding.bottom - _margin - childSize.height,
    );
    final x = textDirection == TextDirection.rtl
        ? anchor.dx - childSize.width
        : anchor.dx;
    var y = anchor.dy + _gap;
    if (y > maxY) y = anchor.dy - _gap - childSize.height;
    return Offset(x.clamp(minX, maxX), y.clamp(minY, maxY));
  }

  @override
  bool shouldRelayout(GlassContextMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      padding != oldDelegate.padding ||
      textDirection != oldDelegate.textDirection;
}
