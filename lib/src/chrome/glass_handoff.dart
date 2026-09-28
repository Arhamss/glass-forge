import 'package:flutter/animation.dart';

/// Where, in a covering route's animation, glass hands over from the chrome
/// beneath to the surface arriving on top.
///
/// Two backdrop filters over the same pixels are flutter#187820 however
/// faint either one is, so the two ramps must not overlap at all: the
/// covered chrome is gone by this point and the covering glass only starts
/// here. Both sides of the handoff read the same number, so they cannot
/// drift apart.
const double glassHandoffPoint = 0.4;

/// The covered chrome's share of a covering route's animation: it fades out
/// entirely before [glassHandoffPoint].
const Interval coveredChromeInterval = Interval(0, glassHandoffPoint);

/// The covering glass's share: it rises from nothing only after
/// [glassHandoffPoint].
const Interval coveringGlassInterval = Interval(glassHandoffPoint, 1);
