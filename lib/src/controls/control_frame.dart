import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';

/// Semantics, focus, keyboard activation and a minimum hit target — the
/// accessible shell every control in `lib/src/controls` builds its visuals
/// inside of.
///
/// [child] is drawn at its own natural size, centred inside a box that is
/// exactly its size, grown to [minimumExtent] on any axis where it is
/// smaller: the frame grows the *hit area*, never the glass or paint a
/// control draws for itself, and never past that minimum into whatever
/// loose space a parent offers. A
/// control that is already 44 × 44 or bigger — most text buttons — is
/// unaffected; a small icon button gets extra, invisible margin to tap in.
///
/// While it holds keyboard focus, and only in keyboard mode, the frame
/// draws a capsule ring just outside [child] in the control role's label
/// colour, so a keyboard user can see where focus is.
///
/// [onActivate] is both what a tap, and Enter or Space while focused, call,
/// and what disables the control when null: no gesture reaches it, no key
/// does anything, and semantics report `enabled: false`. There is
/// deliberately no separate `enabled` flag to keep in sync with it.
///
/// ```dart
/// GlassControlFrame(
///   onActivate: enabled ? () {} : null,
///   semanticLabel: 'Continue',
///   child: myVisual,
/// )
/// ```
class GlassControlFrame extends StatelessWidget {
  /// Creates a control frame around [child].
  const GlassControlFrame({
    required this.child,
    required this.onActivate,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    this.button = true,
    this.toggled,
    this.selected,
    this.inMutuallyExclusiveGroup = false,
    this.slider = false,
    this.value,
    this.increasedValue,
    this.decreasedValue,
    this.onIncrease,
    this.onDecrease,
    this.verticalArrows = false,
    super.key,
  });

  /// The control's own visual — the glass, or its painted stand-in.
  final Widget child;

  /// Called on activation: a tap, a click, or Enter/Space while focused.
  ///
  /// Null disables the control: no gesture, key or semantics action reaches
  /// it, and this is the only thing that decides that — there is no second
  /// `enabled` flag to fall out of sync with it.
  final VoidCallback? onActivate;

  /// The accessible name read for this control.
  ///
  /// Null names the control from [child]'s own semantics instead: a `Text`
  /// child's words become the label. Given, it replaces them.
  final String? semanticLabel;

  /// Where keyboard focus for this control is tracked.
  ///
  /// Null lets this widget own one for its own lifetime.
  final FocusNode? focusNode;

  /// Whether this control requests focus as soon as it is inserted.
  final bool autofocus;

  /// Whether semantics reports this as a button rather than another
  /// interactive role.
  final bool button;

  /// Whether semantics reports a toggle state, and if so, which value.
  ///
  /// Null — the default — reports no toggle state at all, which is right
  /// for `GlassButton` and every other control that is not a two-state
  /// switch. A non-null value sets both `SemanticsFlag.hasToggledState` and
  /// `SemanticsFlag.isToggled` to it, which is what `GlassSwitch` needs.
  final bool? toggled;

  /// Whether semantics reports this as one selected item of a group.
  ///
  /// Null — the default — reports no selection state at all. A non-null
  /// value sets `SemanticsFlag.isSelected`, which is what
  /// `GlassSegmentedControl` needs on the one segment of its group that is
  /// currently chosen — a distinct flag from [toggled], which a screen
  /// reader announces differently (a switch or checkbox, not a tab).
  final bool? selected;

  /// Whether semantics reports this as one of a set of choices only one of
  /// which can be selected — a segment of `GlassSegmentedControl` — so a
  /// screen reader announces its place in the set.
  final bool inMutuallyExclusiveGroup;

  /// Whether semantics reports this as a slider — `GlassSlider`'s only use
  /// of this frame beyond the shared 44 × 44 hit target and focus handling.
  ///
  /// A slider has no single "activate" — see [onActivate], always null for
  /// it — so the frame counts as enabled while [onIncrease] or
  /// [onDecrease] is set, rather than requiring a callback this control has
  /// no use for.
  final bool slider;

  /// The accessible value read for a slider, alongside [semanticLabel].
  final String? value;

  /// What a screen reader announces [value] would become after
  /// [onIncrease].
  final String? increasedValue;

  /// What a screen reader announces [value] would become after
  /// [onDecrease].
  final String? decreasedValue;

  /// Called by the arrow key pointing along the reading direction — right,
  /// or left under [TextDirection.rtl], the way Flutter's own `Slider`
  /// reads them — by the up arrow with [verticalArrows], and, for a
  /// [slider] only, by the increase semantics action. Null leaves the key
  /// unhandled, so it can still do whatever it would elsewhere.
  final VoidCallback? onIncrease;

  /// Called by the arrow key pointing against the reading direction —
  /// left, or right under [TextDirection.rtl] — by the down arrow with
  /// [verticalArrows], and, for a [slider] only, by the decrease semantics
  /// action. Null leaves the key unhandled, so it can still do whatever it
  /// would elsewhere.
  final VoidCallback? onDecrease;

  /// Whether the up and down arrow keys also step, up calling [onIncrease]
  /// and down [onDecrease], as they do for Flutter's own `Slider`.
  ///
  /// False by default: a row of choices — segments, tabs — is a horizontal
  /// control, and the vertical arrows are left for moving on to whatever is
  /// above or below it, as iOS does. Only a slider sets this.
  final bool verticalArrows;

  /// The least a control's hit target may measure on either axis.
  ///
  /// Apple's own minimum for a tappable element, and the floor every
  /// control test in this package holds itself to.
  static const double minimumExtent = 44;

  /// Asserts that a control that fills its width — a slider, a segmented
  /// control, a text field — was given a bounded one.
  ///
  /// In an unbounded `Row` such a control would ask for an infinite width
  /// and fail with a layout error far from the cause; this names the
  /// control and the fix instead.
  static void debugAssertBoundedWidth(BoxConstraints constraints, String name) {
    assert(
      constraints.hasBoundedWidth,
      '$name fills the width it is given, and was given an unbounded one. '
      'In a Row, wrap it in Expanded or Flexible; elsewhere, give it a '
      'width with SizedBox.',
    );
  }

  /// The opacity a disabled control draws its label and paint at.
  static const double disabledOpacity = 0.4;

  /// The colour of a control's moving element — a switch knob, a slider
  /// thumb, a segmented pill — where it is painted rather than glass, on a
  /// glass surface. White in both schemes, the one part of an iOS control
  /// that never flips.
  static const Color paintedElementColor = Color(0xFFFFFFFF);

  bool get _enabled =>
      onActivate != null || onIncrease != null || onDecrease != null;

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;

    Widget result = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: minimumExtent,
        minHeight: minimumExtent,
      ),
      // Size factors of 1: the frame is as big as [child], grown to the
      // 44 x 44 minimum, and no bigger. A bare `Center` expands to fill
      // whatever loose space it is offered, which made a button in a
      // start-aligned column span the whole row and gave a switch in
      // `Align(topLeft)` the whole screen as its hit area.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: _FocusRing(child: child),
      ),
    );

    result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onActivate : null,
      excludeFromSemantics: true,
      child: result,
    );

    result = Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      canRequestFocus: enabled,
      skipTraversal: !enabled,
      onKeyEvent: enabled
          ? (node, event) => _handleKeyEvent(event, rtl: rtl)
          : null,
      child: result,
    );

    return Semantics(
      // One control is one semantics node. With an explicit
      // [semanticLabel], the visual's own semantics — a `Text`, an `Icon`
      // — are dropped so they do not duplicate it. Without one, they are
      // what names the control: a `Text` child's words become this node's
      // label, merged in rather than left as a separate node.
      excludeSemantics: semanticLabel != null,
      container: true,
      button: button,
      slider: slider,
      toggled: toggled,
      selected: selected,
      inMutuallyExclusiveGroup: inMutuallyExclusiveGroup ? true : null,
      enabled: enabled,
      label: semanticLabel,
      value: value,
      increasedValue: increasedValue,
      decreasedValue: decreasedValue,
      onTap: enabled ? onActivate : null,
      // Increase and decrease make a node "adjustable" to a screen reader,
      // which is a slider's role and nothing else's. A segment steps with
      // the arrow keys too, but announcing it as adjustable would describe
      // it wrongly, so only [slider] exposes these as semantics actions.
      onIncrease: enabled && slider ? onIncrease : null,
      onDecrease: enabled && slider ? onDecrease : null,
      child: result,
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event, {required bool rtl}) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (onActivate == null) {
        return KeyEventResult.ignored;
      }
      onActivate!.call();
      return KeyEventResult.handled;
    }
    // The horizontal arrows follow the reading direction: under
    // [TextDirection.rtl] the start of a row is on the right, so the left
    // arrow moves toward its end.
    final backward = rtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;
    final forward = rtl
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;
    if (onDecrease != null &&
        (key == backward ||
            (verticalArrows && key == LogicalKeyboardKey.arrowDown))) {
      onDecrease!.call();
      return KeyEventResult.handled;
    }
    if (onIncrease != null &&
        (key == forward ||
            (verticalArrows && key == LogicalKeyboardKey.arrowUp))) {
      onIncrease!.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

/// A ring around a control's visual while it holds keyboard focus.
///
/// Only in keyboard mode ([FocusHighlightMode.traditional]): a control
/// focused by touch shows nothing, as on iOS, where the focus halo belongs
/// to a hardware keyboard. The ring is drawn just outside the visual, in
/// the control role's label colour — the colour already chosen to read
/// against glass — as a capsule, the shape every control here resolves to.
/// It hugs the visual, not the larger 44 × 44 hit area around it.
class _FocusRing extends StatefulWidget {
  const _FocusRing({required this.child});

  final Widget child;

  @override
  State<_FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<_FocusRing> {
  /// Clear space between the visual and the ring.
  static const double _gap = 3;

  /// The ring's stroke width.
  static const double _width = 2;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode mode) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final show =
        Focus.of(context).hasPrimaryFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (!show) {
      return widget.child;
    }
    final color = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.control,
      size: const Size.square(GlassControlFrame.minimumExtent),
    ).labelColor;
    return CustomPaint(
      foregroundPainter: _FocusRingPainter(color),
      child: widget.child,
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(
      _FocusRingState._gap + _FocusRingState._width / 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _FocusRingState._width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
