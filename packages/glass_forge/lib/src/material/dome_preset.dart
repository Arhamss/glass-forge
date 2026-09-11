part of 'glass_material.dart';

// The dome material: the lens look `liquid_glass_renderer` gives, on this
// package's renderer.
//
// Unlike `apple_presets.dart` these are not fitted against captures. They
// were tuned on the iOS Simulator over the workbench's Photographic backdrop
// -- a soft gradient with no hard structure, where a flat pane reads as
// frosted plastic -- and checked over the pure-black and checkerboard
// backdrops. Change them with a screenshot in hand, not by reasoning alone.

// The rim moves what is behind it 40 pixels inward -- or 0.35 of the
// shape's depth, if that is less -- and the middle magnifies to match:
// about 1.5x at the centre of the workbench's 200-pixel specimen, which is
// clearly a lens without turning the backdrop into a fisheye. Thickness
// hardly touches that; under a dome it mostly sets how wide the lit edge
// is, and 8 keeps it a line rather than a band.
const double _domeThickness = 8;
const double _domeEdgeRefraction = 40;

// No blur. Frost is what turns a lens into a frosted pane: it erases the
// backdrop detail whose magnification is the evidence of a lens. A dome
// samples its backdrop bilinearly (see final_render.frag), so it does not
// need blur to hide nearest-neighbour stair-stepping either.
const double _domeFrost = 0;

// Vivid, the way the upstream renderer's 1.5 default makes it.
const double _domeSaturation = 1.5;

// Dispersion rides on displacement, so on a dome it fringes the whole rim
// region rather than a hairline. Kept low for that reason.
const double _domeChromaticAberration = 0.06;

// A trace of white. Any more reads as a milky veil over a dark backdrop.
const double _domeTintOpacity = 0.04;

// The rim light and the Beer-Lambert darkening under it. On a dark stage
// these are what say "glass" when there is little to refract.
const double _domeHighlight = 1;
const double _domeContour = 0.15;

// From the upper left. Straight down, the default, lights the whole bottom
// edge at once and paints it as a bar; off the axis the highlight gathers
// where the rim turns through the light -- at the corners.
const Offset _domeLightDirection = Offset(-0.7071, -0.7071);
