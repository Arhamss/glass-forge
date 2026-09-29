import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// One brightness scheme's control colours: the parts of a control that are
/// painted in a colour of their own rather than in the surface role's tint
/// and label.
///
/// Labels are not here. A control's label stays the colour its surface role
/// resolves to, because that colour is what the legibility ramp is solved
/// against; an accent that moved it could quietly break the contrast the
/// ramp promises.
///
/// [fill] and [focus] are nullable, and null is the fitted default: the
/// control role's label colour, which is what a slider's fill and a focus
/// ring were drawn in before this token existed. Set them to put an accent
/// there too.
@immutable
class GlassControlColors {
  /// Creates one scheme's control colours.
  const GlassControlColors({
    required this.accent,
    this.knob = const Color(0xFFFFFFFF),
    this.fill,
    this.focus,
  });

  /// The light scheme: Apple's system green, approximated, and a white knob.
  static const GlassControlColors appleLight = GlassControlColors(
    accent: Color(0xFF34C759),
  );

  /// The dark scheme: Apple's dark-mode system green, approximated, and a
  /// white knob.
  static const GlassControlColors appleDark = GlassControlColors(
    accent: Color(0xFF30D158),
  );

  /// The colour of an "on" state: a switch's track when it is on.
  ///
  /// `GlassSwitch.activeTrackColor` still wins over this for one switch.
  final Color accent;

  /// The colour of a control's moving element where it is painted rather
  /// than glass, on a glass surface: a switch knob, a slider thumb, a
  /// segmented control's pill.
  ///
  /// White in both fitted schemes, the one part of an iOS control that
  /// never flips. On content these elements are glass and this colour is
  /// not used.
  final Color knob;

  /// The slider's filled track, or null for the control role's label
  /// colour.
  final Color? fill;

  /// The keyboard focus ring, or null for the control role's label colour.
  final Color? focus;

  /// Returns a copy with the given fields replaced.
  ///
  /// [fill] and [focus] are nullable and `copyWith` cannot tell "leave it"
  /// from "clear it", so clearing one is spelled with the constructor.
  GlassControlColors copyWith({
    Color? accent,
    Color? knob,
    Color? fill,
    Color? focus,
  }) {
    return GlassControlColors(
      accent: accent ?? this.accent,
      knob: knob ?? this.knob,
      fill: fill ?? this.fill,
      focus: focus ?? this.focus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassControlColors &&
        other.accent == accent &&
        other.knob == knob &&
        other.fill == fill &&
        other.focus == focus;
  }

  @override
  int get hashCode => Object.hash(accent, knob, fill, focus);
}

/// Both schemes' control colours.
///
/// The accent system for the controls: a theme that sets
/// `GlassTokens(controls: GlassControlPalette(light: …, dark: …))` recolours
/// every switch, slider, segmented control and focus ring beneath it.
@immutable
class GlassControlPalette {
  /// Creates a pair of schemes. Naming one leaves the other fitted.
  const GlassControlPalette({
    this.light = GlassControlColors.appleLight,
    this.dark = GlassControlColors.appleDark,
  });

  /// The light scheme's colours.
  final GlassControlColors light;

  /// The dark scheme's colours.
  final GlassControlColors dark;

  /// The colours for [brightness].
  GlassControlColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Returns a copy with the given fields replaced.
  GlassControlPalette copyWith({
    GlassControlColors? light,
    GlassControlColors? dark,
  }) {
    return GlassControlPalette(
      light: light ?? this.light,
      dark: dark ?? this.dark,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassControlPalette &&
        other.light == light &&
        other.dark == dark;
  }

  @override
  int get hashCode => Object.hash(light, dark);
}
