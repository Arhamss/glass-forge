import 'package:flutter/foundation.dart';

/// One height a detent sheet rests at.
///
/// Three kinds, because the three questions a caller actually has are
/// different: "a tenth of the screen", "exactly 200 points", and "however
/// tall its contents are". Resolving all three to pixels needs the available
/// height and the measured content height, so [resolve] takes both and each
/// kind ignores the one it does not need.
@immutable
sealed class GlassDetent {
  /// Allows subclasses to be const.
  const GlassDetent();

  /// A fraction of the height available to the sheet, in `(0, 1]`.
  const factory GlassDetent.fraction(double amount) = GlassDetentFraction;

  /// A fixed height in logical pixels.
  const factory GlassDetent.height(double logical) = GlassDetentHeight;

  /// However tall the sheet's child measures.
  const factory GlassDetent.content() = GlassDetentContent;

  /// This detent in logical pixels, never taller than [available].
  double resolve({required double available, required double contentHeight});
}

/// A detent stated as a fraction of the available height.
class GlassDetentFraction extends GlassDetent {
  /// Creates a fractional detent.
  const GlassDetentFraction(this.amount)
    : assert(
        amount > 0 && amount <= 1,
        'a fraction detent runs from just above 0 to 1; a sheet of height 0 '
        'is not a detent, it is a dismissal',
      );

  /// The fraction of the available height, in `(0, 1]`.
  final double amount;

  @override
  double resolve({required double available, required double contentHeight}) =>
      available * amount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlassDetentFraction && other.amount == amount);

  @override
  int get hashCode => Object.hash(GlassDetentFraction, amount);

  @override
  String toString() => 'GlassDetent.fraction($amount)';
}

/// A detent stated in logical pixels.
class GlassDetentHeight extends GlassDetent {
  /// Creates a fixed-height detent.
  const GlassDetentHeight(this.logical)
    : assert(logical > 0, 'a detent must have a positive height');

  /// The height in logical pixels, before the clamp to what is available.
  final double logical;

  @override
  double resolve({required double available, required double contentHeight}) =>
      clampDouble(logical, 0, available);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlassDetentHeight && other.logical == logical);

  @override
  int get hashCode => Object.hash(GlassDetentHeight, logical);

  @override
  String toString() => 'GlassDetent.height($logical)';
}

/// A detent as tall as the sheet's own child.
class GlassDetentContent extends GlassDetent {
  /// Creates a content-measured detent.
  const GlassDetentContent();

  @override
  double resolve({required double available, required double contentHeight}) {
    if (!contentHeight.isFinite) {
      // An unbounded child. See the test: infinity here would take the whole
      // layout with it, and the available height is what the caller meant.
      return available;
    }
    return clampDouble(contentHeight, 0, available);
  }

  @override
  bool operator ==(Object other) => other is GlassDetentContent;

  @override
  int get hashCode => (GlassDetentContent).hashCode;

  @override
  String toString() => 'GlassDetent.content()';
}

/// [detents] in logical pixels, ascending, with duplicates collapsed.
///
/// Sorted rather than asserted-ascending because the three kinds do not
/// commute: `height(400)` and `fraction(0.5)` swap order the moment the
/// window resizes, so a list a caller wrote in ascending order on a phone is
/// descending on a tablet. The order that matters is the resolved one.
List<double> resolveGlassDetents(
  List<GlassDetent> detents, {
  required double available,
  required double contentHeight,
}) {
  final heights =
      detents
          .map(
            (detent) => detent.resolve(
              available: available,
              contentHeight: contentHeight,
            ),
          )
          .toList()
        ..sort();
  final unique = <double>[];
  for (final height in heights) {
    if (unique.isEmpty || height != unique.last) {
      unique.add(height);
    }
  }
  return unique;
}
