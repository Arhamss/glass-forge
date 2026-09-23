import 'package:flutter/widgets.dart';

/// The app's palette.
///
/// Deliberately achromatic. Every scene sits over a photograph, and the
/// photograph is the only thing in the frame allowed to carry colour — an
/// accent hue here would fight the aurora on one scene and the dunes on the
/// next, and lose both times. Selection and state are carried by opacity and
/// weight instead, which is also what Apple's own glass chrome does.
///
/// There is deliberately no `textPrimary` here. Label colour is not the app's
/// to choose on a glass surface: `GlassSurface` resolves one for the scheme
/// its role actually landed in and puts it in the `DefaultTextStyle`, and a
/// bar that flipped to the light scheme wants dark labels. Everything drawn
/// on glass reads that colour through [SurfaceInk] instead of naming its own.
abstract final class Tone {
  /// Behind the photograph, and the colour of a frame that has none yet.
  static const ground = Color(0xFF07080A);

  /// Text over a bare photograph, where no surface has resolved a colour.
  static const overPhoto = Color(0xFFFFFFFF);

  /// A strip painted inside a bare `Glass` to carry a caption.
  ///
  /// `GlassSurface` would have resolved a tint that keeps its own labels
  /// readable, but a raw `Glass` makes no such promise — the clear material
  /// in particular is transparent by design and will happily let a bright
  /// cliff through behind a small label. Painted chrome is what closes that
  /// gap, and painting it is also the only legal option: a second piece of
  /// glass on top of the first is the one composition this renderer cannot
  /// draw.
  static const captionScrim = Color(0x66000000);
}

/// Label colours derived from whatever surface the widget is sitting on.
///
/// The steps are opacities of one inherited colour rather than a set of fixed
/// colours, so the whole hierarchy inverts correctly the moment a surface
/// flips its scheme — which is the behaviour the design system exists to
/// provide, and the easiest one to throw away by writing `Colors.white`.
extension SurfaceInk on BuildContext {
  /// The colour this surface says its labels must be drawn in.
  Color get ink => DefaultTextStyle.of(this).style.color ?? Tone.overPhoto;

  /// Prose under a title, and the value on the right of a slider.
  Color get inkSecondary => ink.withValues(alpha: 0.82);

  /// Units, hints, and the unselected half of a segmented control.
  Color get inkTertiary => ink.withValues(alpha: 0.66);

  /// A separator on this surface.
  Color get inkHairline => ink.withValues(alpha: 0.14);

  /// The fill behind a selected segment, and a slider's unfilled track.
  Color get inkTrack => ink.withValues(alpha: 0.10);

  /// A slider's filled portion.
  ///
  /// Well clear of [inkTrack] rather than a step above it: the fill has to
  /// read as a *level* at a glance, and a fill only slightly stronger than
  /// its track reads as a smudge.
  Color get inkFill => ink.withValues(alpha: 0.26);
}

/// The type scale.
///
/// One family for words and one for numbers, which is the whole system. Geist
/// carries every label, and Geist Mono every measurement — a slider readout
/// that reflows as its digits change is the fastest way to make a control
/// panel feel cheap, and tabular figures cost nothing to ask for.
///
/// No style here sets a colour. `Text` merges its style over the
/// `DefaultTextStyle`, so leaving colour unset is what lets a surface's own
/// label colour through; a caller that wants a step down the hierarchy asks
/// [SurfaceInk] for it.
/// One step of the sans scale, stated the way a type specimen states it:
/// size over leading, in points, with its own weight and tracking.
///
/// A plain function rather than a member of [AppText] because it reads
/// nothing off a context — every step below is a pure function of these four
/// numbers.
TextStyle _sans(double size, double height, FontWeight weight, double track) {
  return TextStyle(
    fontFamily: 'Geist',
    fontSize: size,
    height: height / size,
    fontWeight: weight,
    letterSpacing: track,
  );
}

extension AppText on BuildContext {
  /// A scene's name.
  TextStyle get display => _sans(32, 36, FontWeight.w600, -0.9);

  /// A heading inside a scene.
  TextStyle get title => _sans(19, 24, FontWeight.w600, -0.4);

  /// One sentence of prose under a title.
  TextStyle get body => _sans(15, 21, FontWeight.w400, -0.1);

  /// Buttons, segments, and anything inside a control.
  TextStyle get label => _sans(13, 17, FontWeight.w500, -0.05);

  /// The smallest readable size, for hints under a control.
  TextStyle get caption => _sans(12, 16, FontWeight.w400, 0);

  /// The API call behind what is on screen.
  ///
  /// A step below [mono], because a real signature has to fit at phone width
  /// and truncating the one piece of text a developer came to read would be a
  /// strange thing to do to them.
  TextStyle get code => const TextStyle(
    fontFamily: 'GeistMono',
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w500,
  );

  /// Every number, unit and identifier.
  TextStyle get mono => const TextStyle(
    fontFamily: 'GeistMono',
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// How long this app's own transitions run, with Reduce Motion honoured.
///
/// `glass_forge` collapses its own springs to an instant settle under the
/// setting; nothing does that for the cross-fades and layout changes an app
/// writes itself, so they are gated here. Reading `disableAnimations` as well
/// as `accessibleNavigation` is deliberate: the first is what Android sets
/// from its animator duration scale, the second is what iOS reports.
Duration sceneDuration(BuildContext context, Duration duration) {
  final media = MediaQuery.maybeOf(context);
  final reduced =
      media != null && (media.disableAnimations || media.accessibleNavigation);
  return reduced ? Duration.zero : duration;
}
