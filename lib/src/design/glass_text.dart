import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/design/glass_theme.dart';

/// iOS's body text size, in points: a row label, a sheet's text, a button.
const double glassBodyFontSize = 17;

/// The tracking iOS gives [glassBodyFontSize] text, in logical pixels — the
/// value `CupertinoTextThemeData` uses for the same size.
const double glassBodyLetterSpacing = -0.41;

/// Text in [color] at [fontSize] and [fontWeight], never underlined.
///
/// With no Material or Cupertino ancestor the ambient text style is
/// `WidgetsApp`'s debug fallback — 48-point red monospace, double
/// underlined in yellow — and a style merged onto it keeps whatever it
/// does not name. This one names the size, weight, colour and decoration,
/// so what it is merged onto can no longer make text giant or underlined.
///
/// [inherit] false makes it complete: a [DefaultTextStyle] given it hands
/// its subtree exactly it, which is what a page does. A control merges it
/// with [inherit] true instead, so its labels keep the app's font family
/// and everything else it does not name.
TextStyle glassTextStyle({
  required Color color,
  double fontSize = glassBodyFontSize,
  FontWeight fontWeight = FontWeight.w400,
  double? letterSpacing,
  bool inherit = false,
}) {
  return TextStyle(
    inherit: inherit,
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    decoration: TextDecoration.none,
    textBaseline: TextBaseline.alphabetic,
  );
}

/// The label colour of plain content at [context]: the theme's label for
/// the scheme in effect there, black in light and white in dark by
/// default.
Color glassLabelColorOf(BuildContext context) =>
    GlassTheme.of(context).tokens.tint
        .of(GlassTheme.brightnessOf(context))
        .label;

/// Gives [child] a real text style and icon colour of its own, the way
/// Material's `Scaffold` (through `Material`) and `CupertinoPageScaffold`
/// do.
///
/// Glass pages need nothing but `package:flutter/widgets.dart`, so nothing
/// else above them is guaranteed to have set one: a [DefaultTextStyle]
/// here replaces whatever is ambient, `WidgetsApp`'s underlined debug
/// fallback included, with iOS's 17-point body in [color] — or, left null,
/// in [glassLabelColorOf]. A `GlassSurface` inside still sets its own
/// label colour on top, and an app that wants its own type puts a
/// [DefaultTextStyle] of its own below this one.
class GlassTextDefaults extends StatelessWidget {
  /// Gives [child] the body text style in [color].
  const GlassTextDefaults({required this.child, this.color, super.key});

  /// The colour for text and icons; null takes [glassLabelColorOf].
  final Color? color;

  /// The content the style applies to.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = color ?? glassLabelColorOf(context);
    return DefaultTextStyle(
      style: glassTextStyle(
        color: label,
        letterSpacing: glassBodyLetterSpacing,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: label),
        child: child,
      ),
    );
  }
}
