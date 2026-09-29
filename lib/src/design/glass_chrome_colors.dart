import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// The colours the chrome paints rather than takes from a surface role: the
/// scrim under a modal sheet and the sheets' grab handle.
///
/// One set for both schemes. iOS dims the page under a sheet with black in
/// light and dark alike, and the handle follows the sheet's label colour,
/// which already flips with the scheme.
///
/// Set on a theme as `GlassTokens(chrome: GlassChromeColors(…))`. The
/// defaults are what the chrome drew before this token existed.
@immutable
class GlassChromeColors {
  /// Creates the chrome's colours.
  const GlassChromeColors({
    this.scrim = const Color(0x52000000),
    this.handle,
  });

  /// The colour `showGlassSheet` dims the page beneath with, at full
  /// strength: black at 32 %.
  ///
  /// Read when the sheet is shown; a theme change while it is up does not
  /// recolour its scrim.
  final Color scrim;

  /// The sheets' grab handle, or null for the sheet's own label colour.
  ///
  /// Drawn at 30 % alpha either way, in `showGlassSheet` and
  /// `GlassDetentSheet` alike.
  final Color? handle;

  /// Returns a copy with the given fields replaced.
  ///
  /// [handle] is nullable and `copyWith` cannot tell "leave it" from "clear
  /// it", so clearing it is spelled with the constructor.
  GlassChromeColors copyWith({Color? scrim, Color? handle}) {
    return GlassChromeColors(
      scrim: scrim ?? this.scrim,
      handle: handle ?? this.handle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassChromeColors &&
        other.scrim == scrim &&
        other.handle == handle;
  }

  @override
  int get hashCode => Object.hash(scrim, handle);
}
