import 'package:flutter/widgets.dart';

/// Fades a glass subtree in or out by ramping its refraction, frost, tint
/// and light together, then drops the backdrop pass entirely at zero.
///
/// Not an [Opacity]. Glass has no alpha to fade: a half-transparent
/// refraction is still a full backdrop read, and at zero it is a saveLayer
/// and a stacked filter drawing nothing — which is the flutter#187820 bug
/// this package exists to avoid. So presence ramps the *effect* and, at the
/// bottom of the ramp, stops pushing a pass at all. This is also what Apple
/// does: materializing glass ramps refraction, not alpha.
///
/// Presence applies per backdrop pass, so every shape sharing one material
/// under one [GlassPresence] fades together. A surface that fades on its own
/// while its neighbours stay put already has its own material.
///
/// ```dart
/// GlassPresence(
///   presence: _sheetController,
///   child: Glass(shape: const GlassRoundedRectangle(radius: 28)),
/// )
/// ```
class GlassPresence extends StatelessWidget {
  /// Creates a presence scope.
  const GlassPresence({
    required this.presence,
    required this.child,
    super.key,
  });

  /// 0 is no glass at all; 1 is the material as declared.
  ///
  /// Held by identity, not by value: the object drives one backdrop pass for
  /// its whole life, so animating it costs a rebuilt image filter per frame
  /// and never a rebaked matte.
  final Animation<double> presence;

  /// The subtree whose glass this fades.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPresenceScope(presence: presence, child: child);
  }
}

/// Carries the presence animation down to the shapes it drives.
class GlassPresenceScope extends InheritedWidget {
  /// Creates a scope.
  const GlassPresenceScope({
    required this.presence,
    required super.child,
    super.key,
  });

  /// What drives the glass below this point.
  final Animation<double> presence;

  /// The nearest enclosing presence, if any.
  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<GlassPresenceScope>()
        ?.presence;
  }

  @override
  bool updateShouldNotify(GlassPresenceScope oldWidget) =>
      !identical(oldWidget.presence, presence);
}
