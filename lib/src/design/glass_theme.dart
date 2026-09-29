import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/design/glass_control_colors.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_tokens.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';

/// Tokens, surfaces and motion defaults, as one value.
///
/// Every field defaults, and so does every field of every field, so an
/// override names only what it changes:
///
/// ```dart
/// const GlassThemeData(tokens: GlassTokens(blur: GlassBlurScale(thick: 18)))
/// ```
///
/// is the whole design system with one number moved. There is no `.of` chain
/// to restate and no builder to inherit from.
@immutable
class GlassThemeData {
  /// Creates a theme. Naming one field leaves the rest at their defaults.
  const GlassThemeData({
    this.brightness,
    this.tokens = const GlassTokens(),
    this.surfaces = const GlassSurfaces(),
    this.motion = const GlassMotionDefaults(),
  });

  /// The fitted system, pinned to the light scheme.
  static const GlassThemeData light = GlassThemeData(
    brightness: Brightness.light,
  );

  /// The fitted system, pinned to the dark scheme.
  static const GlassThemeData dark = GlassThemeData(
    brightness: Brightness.dark,
  );

  /// The scheme to resolve in, or null to follow the platform.
  ///
  /// Null is the default because this package does not own the app's
  /// brightness and should not invent an opinion about it. With no value
  /// here, [GlassTheme.brightnessOf] reads
  /// `MediaQuery.platformBrightnessOf`, which is the same source Flutter's
  /// own themes start from, so glass and the rest of the app agree without
  /// either one being told about the other.
  ///
  /// Set it when the app's brightness is not the platform's — a `MaterialApp`
  /// with `themeMode: ThemeMode.dark` on a light phone, or an in-app
  /// appearance switch. Under Material that is one line and restates
  /// nothing:
  ///
  /// ```dart
  /// GlassTheme(
  ///   data: GlassThemeData(brightness: Theme.of(context).brightness),
  ///   child: child,
  /// )
  /// ```
  ///
  /// Reading `Theme.of` here instead would mean this package importing
  /// `package:flutter/material.dart` to serve apps that may be Cupertino or
  /// neither — and `Theme.of` has no `maybeOf`, so a widgets-only app would
  /// silently get Material's fallback light theme rather than its real
  /// platform brightness. Taking the value instead of reaching for it is
  /// what keeps this composing with Flutter's theming rather than competing
  /// with it.
  final Brightness? brightness;

  /// The scales.
  final GlassTokens tokens;

  /// The roles.
  final GlassSurfaces surfaces;

  /// The springs.
  final GlassMotionDefaults motion;

  /// Resolves [role] against a size and a scheme.
  ///
  /// [platformBrightness] is only consulted when [brightness] is null, so a
  /// pinned theme cannot be overridden by the platform behind its back.
  GlassSurfaceStyle resolve(
    GlassSurfaceRole role, {
    required Size size,
    required Brightness platformBrightness,
    Color? backdrop,
  }) {
    return surfaces
        .of(role)
        .resolve(
          size: size,
          platformBrightness: brightness ?? platformBrightness,
          tokens: tokens,
          motionDefaults: motion,
          backdrop: backdrop,
        );
  }

  /// Returns a copy with the given fields replaced.
  ///
  /// [brightness] is nullable and `copyWith` cannot tell "leave it" from
  /// "clear it", so clearing a pinned brightness is spelled
  /// `GlassThemeData(tokens: …, surfaces: …, motion: …)` rather than
  /// `copyWith(brightness: null)`.
  GlassThemeData copyWith({
    Brightness? brightness,
    GlassTokens? tokens,
    GlassSurfaces? surfaces,
    GlassMotionDefaults? motion,
  }) {
    return GlassThemeData(
      brightness: brightness ?? this.brightness,
      tokens: tokens ?? this.tokens,
      surfaces: surfaces ?? this.surfaces,
      motion: motion ?? this.motion,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassThemeData &&
        other.brightness == brightness &&
        other.tokens == tokens &&
        other.surfaces == surfaces &&
        other.motion == motion;
  }

  @override
  int get hashCode => Object.hash(brightness, tokens, surfaces, motion);
}

/// Makes a [GlassThemeData] available to everything beneath it.
///
/// Optional. With no theme anywhere in the tree every lookup here falls back
/// to [fallback], which is the fitted Apple system following the platform's
/// brightness — the same thing a consumer would have written by hand. An app
/// that never wants to think about theming never has to add this widget.
class GlassTheme extends InheritedWidget {
  /// Creates a theme scope.
  const GlassTheme({required this.data, required super.child, super.key});

  /// The theme used where there is no [GlassTheme] above the context.
  static const GlassThemeData fallback = GlassThemeData();

  /// The theme in scope.
  final GlassThemeData data;

  /// The nearest enclosing theme, or null.
  static GlassThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassTheme>()?.data;

  /// The nearest enclosing theme, or [fallback].
  static GlassThemeData of(BuildContext context) =>
      maybeOf(context) ?? fallback;

  /// The scheme to resolve in at [context].
  ///
  /// A pinned [GlassThemeData.brightness] wins; otherwise the platform's,
  /// via `MediaQuery`; otherwise light, for the case where there is no
  /// `MediaQuery` either — a bare `RenderObjectToWidgetAdapter`, or a test
  /// that pumped a widget without one.
  static Brightness brightnessOf(BuildContext context) =>
      maybeOf(context)?.brightness ??
      MediaQuery.maybePlatformBrightnessOf(context) ??
      Brightness.light;

  /// The fitted Apple material for the scheme at [context], in one line.
  ///
  /// This is what belongs on a `GlassLayer`: one layer, one capture, one
  /// material that every `Glass` beneath it inherits.
  static GlassMaterial materialOf(BuildContext context) =>
      GlassMaterial.regular(brightness: brightnessOf(context));

  /// The spring [role] resolves to at [context].
  static GlassMotion motionOf(BuildContext context, GlassMotionRole role) =>
      of(context).motion.of(role);

  /// The control colours for [brightness] — the scheme a control's surface
  /// resolved in, so its accent and its tint always agree — from the theme
  /// at [context].
  static GlassControlColors controlColorsOf(
    BuildContext context,
    Brightness brightness,
  ) => of(context).tokens.controls.of(brightness);

  /// [role], resolved against [size] and the scheme at [context].
  static GlassSurfaceStyle surfaceOf(
    BuildContext context,
    GlassSurfaceRole role, {
    required Size size,
    Color? backdrop,
  }) {
    return of(context).resolve(
      role,
      size: size,
      platformBrightness: brightnessOf(context),
      backdrop: backdrop,
    );
  }

  @override
  bool updateShouldNotify(GlassTheme oldWidget) => oldWidget.data != data;
}
