import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_surface_role_extensions.dart';

/// State for the gallery screen.
///
/// Everything derived here goes back through `glass_forge`'s own resolver
/// rather than being re-implemented, so a readout on this screen cannot
/// drift from what the renderer above it actually drew.
class GalleryState extends Equatable {
  /// Creates a state.
  const GalleryState({
    this.role = GlassSurfaceRole.navigationBar,
    this.backdrop = GlassBackdrop.photographic,
    this.shortSide = 52,
  });

  /// The fitted role set. Not themed here: the gallery's whole subject is
  /// what the defaults do.
  static const surfaces = GlassSurfaces();

  /// The fitted token set, including the flip gate the size slider
  /// crosses.
  ///
  /// The same value `GlassSurfaceSpec.resolve` falls back to when it is
  /// given none, which is why [styleOf] does not pass it: the gallery's
  /// subject is what the defaults do, so naming them twice would only
  /// create somewhere for the two to disagree.
  static const tokens = GlassTokens();

  /// The shortest side the slider offers, in logical pixels.
  static const minShortSide = 40.0;

  /// The longest, in logical pixels.
  ///
  /// Under the narrowest phone the stage lays out in, so the shorter side
  /// of a demonstration surface is always its height — which is what lets
  /// the readouts here be computed from a nominal width without ever
  /// disagreeing with the clamped width the stage really used.
  static const maxShortSide = 220.0;

  /// The role on the stage.
  final GlassSurfaceRole role;

  /// The backdrop behind it.
  final GlassBackdrop backdrop;

  /// The height every demonstration surface is drawn at, in logical
  /// pixels.
  final double shortSide;

  /// What the app tells the package is behind the surface.
  Color get backdropColor => backdrop.meanColor;

  /// The size [role] is drawn at.
  Size get surfaceSize => sizeOf(role);

  /// The size [other] is drawn at.
  Size sizeOf(GlassSurfaceRole other) =>
      Size(other.demonstrationWidth, shortSide);

  /// How much adaptation [other] gets at the current size.
  GlassAdaptation adaptationOf(GlassSurfaceRole other) => surfaces
      .of(other)
      .adaptationFor(sizeOf(other), maxShortSide: tokens.flipMaxShortSide);

  /// How much adaptation the selected [role] gets.
  GlassAdaptation get adaptation => adaptationOf(role);

  /// [other], resolved against the current size and backdrop, in an app
  /// running [ambient].
  GlassSurfaceStyle styleOf(GlassSurfaceRole other, Brightness ambient) =>
      surfaces.of(other).resolve(
        size: sizeOf(other),
        platformBrightness: ambient,
        backdrop: backdropColor,
      );

  /// The selected role, resolved in an app running [ambient].
  GlassSurfaceStyle styleFor(Brightness ambient) => styleOf(role, ambient);

  /// Whether [other] resolves to the same scheme in a light app and a dark
  /// one.
  ///
  /// True is the visible signature of a flip: the surface stopped listening
  /// to the app and started listening to its backdrop.
  bool ignoresAmbientScheme(GlassSurfaceRole other) =>
      styleOf(other, Brightness.light).brightness ==
      styleOf(other, Brightness.dark).brightness;

  /// Returns a copy with the given fields replaced.
  GalleryState copyWith({
    GlassSurfaceRole? role,
    GlassBackdrop? backdrop,
    double? shortSide,
  }) {
    return GalleryState(
      role: role ?? this.role,
      backdrop: backdrop ?? this.backdrop,
      shortSide: shortSide ?? this.shortSide,
    );
  }

  @override
  List<Object?> get props => [role, backdrop, shortSide];
}
