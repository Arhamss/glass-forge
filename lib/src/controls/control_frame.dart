import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Semantics, focus, keyboard activation and a minimum hit target — the
/// accessible shell every control in `lib/src/controls` builds its visuals
/// inside of.
///
/// [child] is drawn at its own natural size, centred inside a box that is
/// never smaller than [minimumExtent] on either axis: the frame grows the
/// *hit area*, never the glass or paint a control draws for itself. A
/// control that is already 44 × 44 or bigger — most text buttons — is
/// unaffected; a small icon button gets extra, invisible margin to tap in.
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
    this.slider = false,
    this.value,
    this.increasedValue,
    this.decreasedValue,
    this.onIncrease,
    this.onDecrease,
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

  /// Whether semantics reports this as a slider — `GlassSlider`'s only use
  /// of this frame beyond the shared 44 × 44 hit target and focus handling.
  ///
  /// A slider has no single "activate" — see [onActivate], always null for
  /// it — so [_enabled] falls back to [onIncrease] and [onDecrease] when
  /// this is set, rather than requiring a callback this control has no use
  /// for.
  final bool slider;

  /// The accessible value read for a slider, alongside [semanticLabel].
  final String? value;

  /// What a screen reader announces [value] would become after
  /// [onIncrease].
  final String? increasedValue;

  /// What a screen reader announces [value] would become after
  /// [onDecrease].
  final String? decreasedValue;

  /// Called by the right or up arrow key while focused, and, for a
  /// [slider] only, by the increase semantics action. Null leaves the key
  /// unhandled, so it can still do whatever it would elsewhere.
  final VoidCallback? onIncrease;

  /// Called by the left or down arrow key while focused, and, for a
  /// [slider] only, by the decrease semantics action. Null leaves the key
  /// unhandled, so it can still do whatever it would elsewhere.
  final VoidCallback? onDecrease;

  /// The least a control's hit target may measure on either axis.
  ///
  /// Apple's own minimum for a tappable element, and the floor every
  /// control test in this package holds itself to.
  static const double minimumExtent = 44;

  bool get _enabled =>
      onActivate != null || onIncrease != null || onDecrease != null;

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;

    Widget result = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: minimumExtent,
        minHeight: minimumExtent,
      ),
      child: Center(child: child),
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
      onKeyEvent: enabled ? _handleKeyEvent : null,
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
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
    if (onDecrease != null &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowDown)) {
      onDecrease!.call();
      return KeyEventResult.handled;
    }
    if (onIncrease != null &&
        (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowUp)) {
      onIncrease!.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
