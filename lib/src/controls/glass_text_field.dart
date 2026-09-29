import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/glass_shape_clipper.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';

/// A single line of editable text in a capsule of glass.
///
/// | | On content | On a glass surface |
/// |---|---|---|
/// | Field body | `Glass` | painted |
///
/// Unlike every other control in this package, focus here is not a state a
/// consumer reaches through a press: it is where the system keyboard's
/// input goes. That is why this widget departs from
/// [GlassControlFrame] — a tap has to place the caret, not merely toggle a
/// value — and instead wraps [EditableText] directly, through the same
/// [TextSelectionGestureDetectorBuilder] `TextField` and `CupertinoTextField`
/// build on, so tap-to-place-caret, double-tap-to-select-word,
/// drag-to-extend and the IME's own composing region all keep working
/// without this widget reimplementing any of them.
///
/// **Focus reads as the glass lighting up, not a ring bolted on top.** On
/// focus the resolved material's `highlight` and `tintOpacity` animate
/// toward a brighter version of themselves — `highlight * 1.35`,
/// `tintOpacity` raised a third of the way to fully opaque — on the theme's
/// `settle` spring, and blur restores the same way. A painted ring would be
/// a second edge fighting the lens profile; see
/// `docs/superpowers/specs/2026-09-14-glass-widgets-design.md`, B5.
///
/// **The caret and selection are never refracted.** [EditableText] is a
/// *sibling* of the field's `Glass` in a `Stack`, not its child, so the
/// caret this package draws is provably outside the glass subtree — a
/// refracted caret would smear and read as a rendering bug. Their colour
/// comes from the surface's own label colour, the same as every other
/// control's label.
///
/// **The keyboard inset.** On focus, and again on every subsequent change
/// to the view's metrics while still focused, a field inside a scroll view
/// scrolls just far enough to sit clear of whatever covers the screen: the
/// keyboard (`MediaQuery.viewInsets`), and a bar or safe area reported
/// through `MediaQuery.padding` — in a `GlassScaffold`, the bottom bar
/// riding the keyboard. It tracks the keyboard's own show/hide animation
/// rather than reacting only to its first or last frame, and a field
/// already in the clear does not move.
///
/// ```dart
/// GlassTextField(
///   controller: controller,
///   placeholder: 'Search',
///   onChanged: (value) => print(value),
/// )
/// ```
///
/// No Material ancestor is required, and the "`package:flutter/widgets.dart`
/// only" rule this package holds every widget to rules out reaching for
/// `AdaptiveTextSelectionToolbar` or the Material/Cupertino drag handles —
/// both live outside the widgets library. That still leaves the one popup
/// menu the widgets library itself can show: [SystemContextMenu], the
/// platform-rendered menu on iOS 16 and above. By default this field uses
/// it wherever [SystemContextMenu.isSupported] says the device can show it —
/// "the system selection toolbar… keeps working" from B5, satisfied with
/// the *actual* system menu rather than a Flutter-painted approximation of
/// one — and shows nothing where it can't (Android, desktop, older iOS).
/// [contextMenuBuilder] overrides that default outright; an app that also
/// imports Material can pass `AdaptiveTextSelectionToolbar.editableText` to
/// get a toolbar everywhere, at the cost of the import this package itself
/// can't take. Likewise [selectionControls] — null keeps this field's own
/// default of zero-size drag handles (the system menu needs none, and a
/// full `TextSelectionControls` that isn't handles-only would otherwise
/// win the toolbar outright and silently block [contextMenuBuilder] — see
/// `text_selection.dart`), and non-null shows this field's own handles
/// through whatever controls the app supplies, e.g.
/// `cupertinoTextSelectionControls`. Every keyboard-driven path (typing,
/// arrow-key caret movement, Cmd/Ctrl+C/V, double-tap-to-select-word) works
/// regardless of either: none of it goes through `TextSelectionControls` or
/// a context menu builder at all.
class GlassTextField extends StatefulWidget {
  /// Creates a text field.
  const GlassTextField({
    this.controller,
    this.placeholder,
    this.leading,
    this.trailing,
    this.shape,
    this.onChanged,
    this.onSubmitted,
    this.backdrop,
    this.selectionControls,
    this.contextMenuBuilder,
    super.key,
  });

  /// Where the field's text lives. Null owns one for this field's own
  /// lifetime.
  final TextEditingController? controller;

  /// Shown in place of the text when it is empty, and read as this field's
  /// accessible label.
  final String? placeholder;

  /// Drawn before the text, inside the field's own padding — usually an
  /// icon.
  final Widget? leading;

  /// Drawn after the text, inside the field's own padding — usually a
  /// clear button.
  final Widget? trailing;

  /// The field's silhouette. Null resolves to the control role's own shape,
  /// a capsule at every size that role ever resolves to.
  final GlassShape? shape;

  /// Called with the field's text on every edit.
  final ValueChanged<String>? onChanged;

  /// Called with the field's text when the IME reports a submit action.
  final ValueChanged<String>? onSubmitted;

  /// What is behind this field, for the same adaptation `GlassSurface`
  /// offers.
  final Color? backdrop;

  /// Selection drag handles. Null keeps this field's own default —
  /// `EmptyTextSelectionControls`, no handles — which this package can
  /// reach without a Material or Cupertino import. Pass a real
  /// implementation (`cupertinoTextSelectionControls`,
  /// `materialTextSelectionControls`) from an app that already imports one
  /// of those to get this field's own drag handles back.
  final TextSelectionControls? selectionControls;

  /// Builds the selection's popup menu. Null keeps this field's own
  /// default: [SystemContextMenu.editableText] wherever
  /// [SystemContextMenu.isSupported] says the device can show it (iOS 16+),
  /// nothing elsewhere. Pass a builder — most usefully
  /// `AdaptiveTextSelectionToolbar.editableText` from an app that imports
  /// Material — to get a Flutter-painted menu everywhere else too.
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver
    implements TextSelectionGestureDetectorBuilderDelegate {
  static const double _height = GlassControlFrame.minimumExtent;
  static const EdgeInsetsGeometry _padding = EdgeInsets.symmetric(
    horizontal: 16,
  );
  static const double _gap = 8;
  static const double _fontSize = 17;

  /// How much brighter the material reads at full focus. Both numbers are
  /// this widget's own judgement call, not a fitted Apple constant like
  /// `GlassMaterial.regular`'s: Apple names "brighter on focus" as the
  /// behaviour (see the class doc) without publishing the delta. 1.35×
  /// lifts the rim highlight enough to read as lit without blowing past the
  /// dome preset's own highlight; the tint opacity move keeps a third of
  /// its remaining headroom to full opacity so the capsule visibly
  /// thickens without ever turning solid.
  static const double _focusHighlightBoost = 1.35;
  static const double _focusTintOpacityLift = 1 / 3;

  final GlobalKey<EditableTextState> _editableKey =
      GlobalKey<EditableTextState>();
  late final TextSelectionGestureDetectorBuilder _gestureBuilder =
      TextSelectionGestureDetectorBuilder(delegate: this);

  TextEditingController? _ownedController;
  FocusNode? _ownedFocusNode;

  /// The focus spring's own domain: 0 unfocused, [_focusTravel] focused —
  /// not a raw 0..1 fraction, so `GlassMotion`'s pixel-stated tolerance
  /// (`GlassMotion.settleDistance`, `GlassMotion.settleVelocity`) means what
  /// it says, the same reason `GlassSwitch` springs a pixel offset rather
  /// than a fraction of its track.
  static const double _focusTravel = 100;

  late final AnimationController _focus;

  bool _scrollIntoViewScheduled = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());

  FocusNode get _focusNode => _ownedFocusNode ??= FocusNode();

  @override
  GlobalKey<EditableTextState> get editableTextKey => _editableKey;

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  @override
  void initState() {
    super.initState();
    _focus = AnimationController(vsync: this, upperBound: _focusTravel);
    _focusNode.addListener(_handleFocusChange);
    GlassReduceMotion.instance.addListener(_onReduceMotionChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GlassReduceMotion.instance.removeListener(_onReduceMotionChanged);
    _focusNode.removeListener(_handleFocusChange);
    _ownedFocusNode?.dispose();
    _ownedController?.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // The keyboard's show/hide animation fires this repeatedly as
    // `MediaQuery`'s view insets move; re-running `ensureVisible` on every
    // call tracks that animation instead of only reacting to its first or
    // last frame. See the class doc's "keyboard inset" section.
    if (_focusNode.hasFocus) {
      _lastCovered = null;
      _scheduleEnsureVisible();
    }
  }

  void _handleFocusChange() {
    final focused = _focusNode.hasFocus;
    _animateFocusTo(focused ? _focusTravel : 0);
    if (focused) {
      _lastCovered = null;
      _scheduleEnsureVisible();
    }
  }

  void _onReduceMotionChanged() {
    if (GlassReduceMotion.instance.value && _focus.isAnimating) {
      _focus.value = _focusNode.hasFocus ? _focusTravel : 0;
    }
  }

  void _animateFocusTo(double target) {
    if (GlassReduceMotion.instance.value) {
      _focus.value = target;
      return;
    }
    final motion = GlassTheme.motionOf(context, GlassMotionRole.settle);
    _focus.animateWith(
      SpringSimulation(
        motion.spring,
        _focus.value,
        target,
        0,
        tolerance: motion.tolerance,
      ),
    );
  }

  /// Reveals the field after this frame, so it has already laid out under
  /// the current insets before anything measures where it is.
  /// [_scrollIntoViewScheduled] collapses every call within one frame (a
  /// focus change and a metrics change can land in the same frame) into a
  /// single post-frame callback.
  void _scheduleEnsureVisible() {
    if (_scrollIntoViewScheduled) {
      return;
    }
    _scrollIntoViewScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollIntoViewScheduled = false;
      if (!mounted || !_focusNode.hasFocus) {
        return;
      }
      _reveal();
    });
  }

  /// The covered edges [_reveal] last scrolled clear of.
  EdgeInsets? _lastCovered;

  /// Scrolls the nearest [Scrollable] just far enough that the field sits
  /// in the part of its viewport nothing covers.
  ///
  /// A viewport does not know what is drawn over it. A `GlassScaffold` body
  /// spans the whole screen under its bars, and a full-screen list under a
  /// keyboard is not shrunk by anything, so revealing the field inside the
  /// viewport alone can leave it under the keyboard, or under a bottom bar
  /// riding the keyboard. So the field reads what covers the screen from
  /// the scrollable's `MediaQuery` — the larger of `viewInsets.bottom` (the
  /// keyboard) and `padding.bottom` (a bar, or the home indicator), and
  /// `padding.top` — and asks the viewport to reveal a rect grown by the
  /// part of the viewport those cover. A field already in the clear does
  /// not move.
  ///
  /// The scrollable's `MediaQuery` rather than the field's own: a list
  /// takes the vertical padding out of its children's `MediaQuery`.
  ///
  /// What covers the screen can settle a frame after the insets do — a
  /// `GlassScaffold` measures its bar's new height at the end of a frame —
  /// so while the covered edges keep changing, this checks again after the
  /// next frame.
  void _reveal() {
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    if (box is! RenderBox || !box.hasSize || scrollable == null) {
      return;
    }
    final viewport = scrollable.context.findRenderObject();
    final media = MediaQuery.maybeOf(scrollable.context);
    var above = 0.0;
    var below = 0.0;
    var covered = EdgeInsets.zero;
    if (viewport is RenderBox && viewport.hasSize && media != null) {
      covered = EdgeInsets.only(
        top: media.padding.top,
        bottom: math.max(media.viewInsets.bottom, media.padding.bottom),
      );
      final top = viewport.localToGlobal(Offset.zero).dy;
      final bottom = top + viewport.size.height;
      above = math.max(0, covered.top - top);
      below = math.max(0, bottom - (media.size.height - covered.bottom));
    }
    final duration = GlassReduceMotion.instance.value
        ? Duration.zero
        : _revealDuration;
    box.showOnScreen(
      rect: Rect.fromLTRB(
        0,
        -above,
        box.size.width,
        box.size.height + below,
      ),
      duration: duration,
      curve: Curves.easeOut,
    );
    if (covered != _lastCovered) {
      _lastCovered = covered;
      _scheduleEnsureVisible();
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  static const Duration _revealDuration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = GlassTheme.surfaceOf(
          context,
          GlassSurfaceRole.control,
          size: Size(constraints.maxWidth, _height),
          backdrop: widget.backdrop,
        );
        final onGlass = GlassHostScope.isOnGlass(context);
        final shape = widget.shape ?? style.shape;
        final brighter = style.material.copyWith(
          highlight: style.material.highlight * _focusHighlightBoost,
          tintOpacity:
              style.material.tintOpacity +
              (1 - style.material.tintOpacity) * _focusTintOpacityLift,
        );

        return SizedBox(
          width: constraints.maxWidth,
          height: _height,
          child: AnimatedBuilder(
            animation: _focus,
            builder: (context, child) {
              final t = _focus.value / _focusTravel;
              final material = style.material.copyWith(
                highlight: _lerp(
                  style.material.highlight,
                  brighter.highlight,
                  t,
                ),
                tintOpacity: _lerp(
                  style.material.tintOpacity,
                  brighter.tintOpacity,
                  t,
                ),
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: onGlass
                        ? _paintedBody(shape: shape, material: material)
                        : Glass(shape: shape, material: material),
                  ),
                  Positioned.fill(child: child!),
                ],
              );
            },
            child: _foreground(style),
          ),
        );
      },
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// [GlassTextField.contextMenuBuilder], or this field's own default:
  /// [SystemContextMenu.editableText] where the device can show it, and no
  /// builder at all — not one that builds an empty widget — where it can't.
  /// `SystemContextMenu.editableText` itself asserts if built on a device
  /// [SystemContextMenu.isSupported] says can't show it, so this has to be
  /// resolved before `EditableText` is built, not inside a builder that
  /// runs on demand.
  EditableTextContextMenuBuilder? _resolveContextMenuBuilder(
    BuildContext context,
  ) {
    final custom = widget.contextMenuBuilder;
    if (custom != null) {
      return custom;
    }
    if (!SystemContextMenu.isSupported(context)) {
      return null;
    }
    return (context, editableTextState) =>
        SystemContextMenu.editableText(editableTextState: editableTextState);
  }

  Widget _paintedBody({
    required GlassShape shape,
    required GlassMaterial material,
  }) {
    return ClipPath(
      clipper: GlassShapeClipper(shape),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: material.tint.withValues(alpha: material.tintOpacity),
        ),
      ),
    );
  }

  /// Leading, the editable text and its placeholder, and trailing — the
  /// part of this field drawn *above* the glass, laid out once as
  /// [AnimatedBuilder.child] so the focus spring's every tick rebuilds only
  /// the background behind it.
  ///
  /// Wrapped in its own [GlassHostScope]: this content sits visually on top
  /// of the field's own glass (or its painted stand-in) even though it is a
  /// `Stack` sibling rather than that `Glass`'s child, and "at most one
  /// glass surface at any point on screen" applies to what a leading or
  /// trailing widget draws here exactly as it would inside a glass toolbar.
  Widget _foreground(GlassSurfaceStyle style) {
    return GlassHostScope(
      child: Padding(
        padding: _padding,
        child: Row(
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: _gap),
            ],
            Expanded(child: _editableStack(style)),
            if (widget.trailing != null) ...[
              const SizedBox(width: _gap),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _editableStack(GlassSurfaceStyle style) {
    final placeholder = widget.placeholder;
    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        if (placeholder != null)
          ExcludeSemantics(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, child) =>
                  value.text.isEmpty ? child! : const SizedBox.shrink(),
              child: Text(
                placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: style.labelColor.withValues(alpha: 0.5),
                  fontSize: _fontSize,
                ),
              ),
            ),
          ),
        Semantics(
          textField: true,
          label: placeholder,
          child: _gestureBuilder.buildGestureDetector(
            behavior: HitTestBehavior.translucent,
            child: EditableText(
              key: _editableKey,
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(
                color: style.labelColor,
                fontSize: _fontSize,
              ),
              cursorColor: style.labelColor,
              backgroundCursorColor: style.labelColor.withValues(alpha: 0.2),
              selectionColor: style.labelColor.withValues(alpha: 0.24),
              selectionControls:
                  widget.selectionControls ?? _defaultSelectionControls,
              // A real `selectionControls` implementation renders actual
              // handles; this field's own default,
              // `EmptyTextSelectionControls`, renders a zero-size one —
              // showing handles for it would ask `EditableText` to place
              // handles nothing occupies.
              showSelectionHandles: widget.selectionControls != null,
              contextMenuBuilder: _resolveContextMenuBuilder(context),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
            ),
          ),
        ),
      ],
    );
  }
}

/// [EmptyTextSelectionControls]'s zero-size handles, but with
/// [TextSelectionHandleControls] mixed in on top so
/// `EditableTextState.showToolbar` defers the popup menu to
/// [GlassTextField.contextMenuBuilder] instead of this class's own (equally
/// empty) `buildToolbar`.
///
/// `text_selection.dart`'s own precedence rule is blunt:
/// `TextSelectionOverlay.showToolbar` uses a plain `TextSelectionControls`'
/// own `buildToolbar` outright whenever one is supplied, and only falls
/// back to `contextMenuBuilder` when `selectionControls` is null or mixes in
/// `TextSelectionHandleControls`. `EmptyTextSelectionControls` alone does
/// neither — passing it straight through would silently swallow every
/// context menu this field tries to show, system or custom.
class _GlassSelectionHandleControls extends EmptyTextSelectionControls
    with TextSelectionHandleControls {}

/// This field's own default [GlassTextField.selectionControls]: zero-size
/// handles that never contest [GlassTextField.contextMenuBuilder] for the
/// toolbar. Not `const` — matching `emptyTextSelectionControls` itself,
/// which the framework also declares as a plain `final`, not `const`.
final TextSelectionControls _defaultSelectionControls =
    _GlassSelectionHandleControls();
