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

  /// The least a control's hit target may measure on either axis.
  ///
  /// Apple's own minimum for a tappable element, and the floor every
  /// control test in this package holds itself to.
  static const double minimumExtent = 44;

  bool get _enabled => onActivate != null;

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
      // The control's own visual — a `Text` label, an `Icon` — would
      // otherwise contribute its own semantics too, merging into this
      // node's and duplicating [semanticLabel] onto it. One control is one
      // semantics node.
      excludeSemantics: true,
      container: true,
      button: button,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? onActivate : null,
      child: result,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter && key != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    onActivate?.call();
    return KeyEventResult.handled;
  }
}
