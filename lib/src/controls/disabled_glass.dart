import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/widgets/glass_presence.dart';

/// Dims a control's glass while the control is disabled.
///
/// A disabled control draws its label and painted parts at
/// [GlassControlFrame.disabledOpacity] through an `Opacity`, but an
/// `Opacity` never reaches glass: the layer renders it, not the subtree.
/// So the glass is dimmed the way glass fades everywhere in this package,
/// through a [GlassPresence] at the same 0.4 — refraction, frost, tint and
/// light ramped down together. Under an enclosing presence (a sheet
/// rising, a covered bar) the two multiply, so the glass still fades with
/// its surroundings.
///
/// The presence objects are shared, by identity, between every disabled
/// control under the same enclosing presence: presence identity is part of
/// what puts shapes in one backdrop pass, and disabled controls should
/// share one rather than cost one each.
///
/// Internal: not exported.
class DisabledGlassPresence extends StatelessWidget {
  /// Dims [child]'s glass while [disabled].
  const DisabledGlassPresence({
    required this.disabled,
    required this.child,
    super.key,
  });

  /// Whether the control is disabled.
  final bool disabled;

  /// The control's glass.
  final Widget child;

  static const Animation<double> _alone = AlwaysStoppedAnimation<double>(
    GlassControlFrame.disabledOpacity,
  );

  static final Expando<Animation<double>> _under = Expando();

  @override
  Widget build(BuildContext context) {
    if (!disabled) {
      return child;
    }
    final outer = GlassPresenceScope.maybeOf(context);
    final presence = outer == null
        ? _alone
        : (_under[outer] ??= _Dimmed(outer));
    return GlassPresence(presence: presence, child: child);
  }
}

/// [parent], times [GlassControlFrame.disabledOpacity].
class _Dimmed extends Animation<double> with AnimationWithParentMixin<double> {
  _Dimmed(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value * GlassControlFrame.disabledOpacity;
}
