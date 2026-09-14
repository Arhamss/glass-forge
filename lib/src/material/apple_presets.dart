part of 'glass_material.dart';

// Materials fitted to Apple's shipping look.
//
// The numbers here were fitted against real iOS 27 captures rather than
// chosen by eye. Change them only with a comparison capture in hand.
//
// A `part of` this library, rather than a separate importable file, because
// [GlassMaterial.regular] and [GlassMaterial.clear] are the only public
// surface these numbers need — keeping them library-private avoids a second
// public name (an `AppleGlassPresets` extension) for the same values.

const double _appleThickness = 12;
const double _appleEdgeRefraction = 27.42;
const double _appleContour = 0.08;

// Regular — adapts to what is behind it.
const double _appleRegularFrostDark = 5;
const double _appleRegularFrostLight = 7;
const double _appleRegularSaturationDark = 2.6;
const double _appleRegularSaturationLight = 0.9;
const Color _appleRegularTintDark = Color(0xFF3A3A3A);
const Color _appleRegularTintLight = Color(0xFFFDFCFD);
const double _appleRegularTintOpacityDark = 0.56;
const double _appleRegularTintOpacityLight = 0.407;
const double _appleRegularHighlight = 1;

// Clear — no adaptation, dimming layer instead.
const double _appleClearFrost = 0;
const double _appleClearTintOpacity = 0;
const double _appleClearHighlight = 0.25;
