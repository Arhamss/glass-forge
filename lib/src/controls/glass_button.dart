import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/controls/disabled_glass.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/motion/glass_press_stretch.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/glass_shape_clipper.dart';
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
/// the callback never runs. Like every control in this package except
/// `GlassTextField`, it shares one internal frame for that behaviour, plus
/// semantics, keyboard activation and the 44 × 44 minimum hit target.
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
    this.toggled,
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
    this.toggled,
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
  /// Required on [GlassButton.icon]; optional here. Null reads [child]'s
  /// own semantics as the name, so a `Text` child names the button with its
  /// words; given, this replaces them.
  final String? semanticLabel;

  /// Where keyboard focus for this button is tracked. Null owns one for
  /// this button's own lifetime.
  final FocusNode? focusNode;

  /// Whether this button requests focus as soon as it is inserted.
  final bool autofocus;

  /// Whether this button is on, for a button that toggles something —
  /// mute, bold, favourite — rather than running a one-off action.
  ///
  /// Null — the default — reports no toggle state at all, which is right
  /// for an ordinary button. A non-null value sets the toggled semantics
  /// flag, so a screen reader announces the button
  /// as on or off rather than leaving the state to its looks alone. This
  /// only reports the state: flipping it on press, and drawing it, stay
  /// with the caller, which owns the value.
  final bool? toggled;

  final EdgeInsetsGeometry _padding;

  static const EdgeInsetsGeometry _labelPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 10,
  );

  static const EdgeInsetsGeometry _iconPadding = EdgeInsets.all(6);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GlassControlFrame(
      onActivate: onPressed,
      semanticLabel: semanticLabel,
      focusNode: focusNode,
      autofocus: autofocus,
      toggled: toggled,
      child: _MeasuredBody(
        measure: backdrop != null,
        builder: (context, size) => _body(context, size, enabled: enabled),
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
      alpha: enabled ? 1 : GlassControlFrame.disabledOpacity,
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
        clipper: GlassShapeClipper(resolvedShape),
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

    // The control role's own material, which [labelColor] was resolved
    // against: inheriting the layer's instead would leave the label's
    // contrast promise about a surface that is not drawn.
    final glass = DisabledGlassPresence(
      disabled: !enabled,
      child: Glass(
        shape: resolvedShape,
        material: style.material,
        child: label,
      ),
    );
    // Always the same tree, enabled or not: swapping `InteractiveGlass` in
    // and out with [onPressed] remounted it and the glass beneath it. A
    // disabled button just takes no pointer, so it neither presses nor
    // glows.
    return IgnorePointer(
      ignoring: !enabled,
      child: InteractiveGlass(
        pressStretch: pressStretch,
        glow: glow,
        child: glass,
      ),
    );
  }
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

/// Builds a button's body for the size it is actually laid out at.
///
/// The surface a button resolves depends on its size only through the
/// size gate on adaptation — a small control may flip its scheme against a
/// [GlassButton.backdrop], a large one only adapts — and only when a
/// backdrop is given. A button's size is its label's, which is not known
/// until it has laid out, and the space its parent offers says nothing
/// about it: in a list, the height offered is infinite, which read as a
/// huge surface and never flipped.
///
/// So with [measure] on, the body is first built for a best guess — the
/// offered width, and the 44-point minimum height a control is laid out
/// at unless its content is taller — then measured, and rebuilt once for
/// the measured size if that differs. Without a backdrop nothing depends
/// on the size, and nothing is measured.
class _MeasuredBody extends StatefulWidget {
  const _MeasuredBody({required this.measure, required this.builder});

  final bool measure;
  final Widget Function(BuildContext context, Size size) builder;

  @override
  State<_MeasuredBody> createState() => _MeasuredBodyState();
}

class _MeasuredBodyState extends State<_MeasuredBody> {
  Size? _measured;

  void _onSize(Size size) {
    if (mounted && widget.measure && size != _measured) {
      setState(() => _measured = size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final guess = Size(
          constraints.maxWidth,
          math.min(constraints.maxHeight, GlassControlFrame.minimumExtent),
        );
        final body = widget.builder(context, _measured ?? guess);
        if (!widget.measure) {
          return body;
        }
        return _ReportSize(onSize: _onSize, child: body);
      },
    );
  }
}

/// Reports its child's size after each layout that changes it, at the end
/// of the frame: a rebuild from inside layout would throw.
class _ReportSize extends SingleChildRenderObjectWidget {
  const _ReportSize({required this.onSize, required Widget super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportSize(onSize);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderReportSize).onSize = onSize;
  }
}

class _RenderReportSize extends RenderProxyBox {
  _RenderReportSize(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final laidOut = size;
    if (laidOut == _reported) {
      return;
    }
    _reported = laidOut;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(laidOut));
  }
}
