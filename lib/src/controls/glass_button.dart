import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/motion/glass_press_stretch.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';

/// A tappable capsule of glass, or its painted stand-in on a glass surface.
///
/// Resolves `GlassSurfaceRole.control` for its material, shape and label
/// colour — never a hard-coded colour — and never draws a `Glass` inside
/// another one: under [GlassHostScope] this paints a flat tint instead, with
/// a scale on press and no glow, which is what "always avoid glass on
/// glass" means for a button sitting in a glass toolbar.
///
/// ```dart
/// GlassButton(
///   onPressed: () {},
///   child: const Text('Continue'),
/// )
/// ```
///
/// `onPressed: null` disables it: 40% label opacity, no press response, and
/// the callback never runs — see [GlassControlFrame], which every control
/// in this package shares for that behaviour, plus semantics, keyboard
/// activation and the 44 × 44 minimum hit target.
class GlassButton extends StatelessWidget {
  /// Creates a button around [child].
  const GlassButton({
    required this.onPressed,
    required this.child,
    this.shape,
    this.backdrop,
    this.pressStretch = const GlassPressStretch(),
    this.glow = true,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : _padding = _labelPadding;

  /// Creates an icon-only button.
  ///
  /// [semanticLabel] is required and typed `String` here, rather than the
  /// `String?` the unnamed constructor and the shared field both carry: an
  /// icon has no text of its own for a screen reader to fall back to, so
  /// this constructor holds callers to a real label at compile time. An
  /// initializing formal with an explicit, narrower type — `String`, where
  /// the field itself is `String?` — is what makes that a static guarantee
  /// rather than a debug-only assert.
  const GlassButton.icon({
    required this.onPressed,
    required Widget icon,
    required String this.semanticLabel,
    this.backdrop,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : child = icon,
       shape = null,
       pressStretch = const GlassPressStretch(),
       glow = true,
       _padding = _iconPadding;

  /// Called on activation. Null renders this button disabled.
  final VoidCallback? onPressed;

  /// The button's content — usually a `Text` or an `Icon`.
  final Widget child;

  /// The button's silhouette. Null resolves to the control role's own
  /// shape, a capsule at every size that role ever resolves to.
  final GlassShape? shape;

  /// What is behind this button, for the same adaptation `GlassSurface`
  /// offers — flip or thicken the tint until its label clears contrast.
  final Color? backdrop;

  /// How far this button reaches toward a held finger.
  ///
  /// Only meaningful on content, where this is real glass: the painted
  /// stand-in drawn under [GlassHostScope] scales on press and never
  /// stretches.
  final GlassPressStretch pressStretch;

  /// Whether a press lights the touch glow.
  ///
  /// Always false under [GlassHostScope], regardless of this flag: a
  /// painted button has no glass for a glow to spread onto. On content,
  /// `false` keeps the press's depth, scale and stretch but stops this
  /// button's own press from lighting its layer's shared glow channel —
  /// every neighbouring surface still glows normally when pressed itself.
  final bool glow;

  /// The accessible name read for this button.
  ///
  /// Required on [GlassButton.icon]; optional here, where [child] is
  /// usually text a screen reader can already read for itself.
  final String? semanticLabel;

  /// Where keyboard focus for this button is tracked. Null owns one for
  /// this button's own lifetime.
  final FocusNode? focusNode;

  /// Whether this button requests focus as soon as it is inserted.
  final bool autofocus;

  final EdgeInsetsGeometry _padding;

  static const EdgeInsetsGeometry _labelPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 10,
  );

  static const EdgeInsetsGeometry _iconPadding = EdgeInsets.all(6);

  /// The label opacity a disabled button draws at.
  static const double _disabledOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GlassControlFrame(
      onActivate: onPressed,
      semanticLabel: semanticLabel,
      focusNode: focusNode,
      autofocus: autofocus,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _body(context, constraints.biggest, enabled: enabled);
        },
      ),
    );
  }

  Widget _body(BuildContext context, Size size, {required bool enabled}) {
    final style = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.control,
      size: size,
      backdrop: backdrop,
    );
    final resolvedShape = shape ?? style.shape;
    final labelColor = style.labelColor.withValues(
      alpha: enabled ? 1 : _disabledOpacity,
    );

    final label = Padding(
      padding: _padding,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: labelColor),
        child: IconTheme.merge(
          data: IconThemeData(color: labelColor),
          child: child,
        ),
      ),
    );

    if (GlassHostScope.isOnGlass(context)) {
      final painted = ClipPath(
        clipper: _ButtonShapeClipper(resolvedShape),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style.material.tint.withValues(
              alpha: style.material.tintOpacity,
            ),
          ),
          child: label,
        ),
      );
      return enabled ? _PaintedPressScale(child: painted) : painted;
    }

    if (!enabled) {
      return Glass(shape: resolvedShape, child: label);
    }

    return InteractiveGlass(
      pressStretch: pressStretch,
      glow: glow,
      child: Glass(shape: resolvedShape, child: label),
    );
  }
}

/// Clips to [shape] at the real, laid-out size.
///
/// A local copy of the same two lines `GlassShapeClipper` in `glass.dart`
/// runs — not a reuse of that class, which is `@visibleForTesting` and
/// exists for tests to reach into `Glass`'s own clip, not for other widgets
/// in this package to paint with.
class _ButtonShapeClipper extends CustomClipper<Path> {
  const _ButtonShapeClipper(this.shape);

  final GlassShape shape;

  @override
  Path getClip(Size size) =>
      shape.toBorder(size).getOuterPath(Offset.zero & size);

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) =>
      oldClipper is! _ButtonShapeClipper || oldClipper.shape != shape;
}

/// A scale-on-press for the painted body drawn under [GlassHostScope].
///
/// No `Glass`, no glow, no press-stretch — a flat tint has no lens to reach
/// with and no backdrop pass to light. `Listener`, not `GestureDetector`:
/// this only drives a visual, and a second tap recognizer here would enter
/// the same gesture arena as `GlassControlFrame`'s, which is the one that
/// actually calls `onActivate`.
class _PaintedPressScale extends StatefulWidget {
  const _PaintedPressScale({required this.child});

  final Widget child;

  @override
  State<_PaintedPressScale> createState() => _PaintedPressScaleState();
}

class _PaintedPressScaleState extends State<_PaintedPressScale> {
  bool _pressed = false;

  void _setPressed({required bool value}) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = GlassReduceMotion.instance.value;
    return Listener(
      onPointerDown: (_) => _setPressed(value: true),
      onPointerUp: (_) => _setPressed(value: false),
      onPointerCancel: (_) => _setPressed(value: false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
