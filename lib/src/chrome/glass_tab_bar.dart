import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_shadow_painter.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/design/glass_tint.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/motion/settle_spring.dart';
import 'package:glass_forge/src/shapes/glass_shape_clipper.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';
import 'package:glass_forge/src/widgets/glass_presence.dart';

/// One destination in a [GlassTabBar].
@immutable
class GlassTab {
  /// Creates a tab.
  const GlassTab({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.semanticLabel,
  });

  /// Drawn while this tab is not the selected one — and while it is, too,
  /// when [activeIcon] is null.
  final Widget icon;

  /// Drawn in place of [icon] while this tab is selected. Null keeps [icon].
  final Widget? activeIcon;

  /// The tab's visible label, and the name a screen reader reads for it
  /// unless [semanticLabel] is given.
  final String label;

  /// The name a screen reader reads for this tab, in place of [label]: for
  /// a short or abbreviated label that needs a fuller name. Null reads
  /// [label].
  final String? semanticLabel;
}

/// A floating capsule of tabs whose selection is a clear glass lens that
/// springs from tab to tab.
///
/// ```dart
/// GlassScaffold(
///   body: pages[index],
///   bottomBar: GlassTabBar(
///     tabs: const [
///       GlassTab(icon: Icon(Icons.home_outlined), label: 'Home'),
///       GlassTab(icon: Icon(Icons.search), label: 'Search'),
///     ],
///     currentIndex: index,
///     onTap: (next) => setState(() => index = next),
///   ),
/// )
/// ```
///
/// Only the selection is glass. The bar itself is painted: a semi-opaque
/// capsule in the navigationBar role's shape and shadow, filled with
/// [backgroundColor] or the role's tint, with a hairline rim and the bottom
/// safe-area inset built in. It has no blur and reads no backdrop, so the
/// lens — a clear glass in a material of its own, [selectionMaterial], one
/// tab wide — bends the painted bar and whatever shows through it, and is
/// never a second backdrop pass over other glass.
///
/// A bouncy spring — the theme's [GlassMotionRole.settle], SwiftUI's
/// `.bouncy` unless a theme retunes it — moves the lens, and the lens
/// squashes along its travel with its speed: narrower and taller the
/// faster it goes, back to its own shape once it lands. A tap aims it at
/// the new tab. A drag anywhere along the bar keeps re-aiming it at the
/// finger, clamped to the bar, with a selection click each time the finger
/// crosses into another tab, and the release commits the tab under the
/// finger; a cancelled drag sends the lens back. Nothing is reported until
/// the finger lifts, and a release on the current tab reports nothing. The
/// selection always ends up at [currentIndex]: an owner that declines the
/// tab a drag was released on, or has not rebuilt with it by the next
/// frame, gets the lens sent back, and only the tab at [currentIndex] ever
/// reports itself selected.
///
/// The bar fades with the enclosing presence — a `GlassScaffold`'s, while
/// a route covers it — and so does the lens, so a faded bar never leaves a
/// lens behind.
///
/// Under Reduce Motion the lens is still glass, but it moves instantly and
/// never squashes.
///
/// Inside other glass — a sheet, say — the selection paints too: a flat
/// pill in place of the lens, since glass is never built inside glass.
///
/// The arrow keys move keyboard focus from tab to tab, through the app's
/// ordinary directional focus traversal; Enter or Space then selects the
/// focused tab. They do not change the selection themselves, because
/// selecting a tab navigates.
///
/// The bar spans the width it is given, less [margin], up to [maxWidth]
/// (480 points unless you pass another), and is centred past that — so on
/// a tablet it stays a capsule under the content rather than a strip across
/// the screen.
///
/// Every tab gets an equal share of the bar's width. Use at most five, as
/// iOS does: with more tabs than leave each one 44 points, the bar reports
/// an error in debug builds.
///
/// Each tab is its own selectable button through the frame every control
/// shares —
/// semantics, keyboard focus, Enter and Space, a 44 × 44 minimum hit
/// target — and exactly the one at [currentIndex] reports itself selected.
class GlassTabBar extends StatefulWidget {
  /// Creates a tab bar.
  const GlassTabBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    this.backdrop,
    this.backgroundColor,
    this.selectionMaterial,
    this.maxWidth = defaultMaxWidth,
    super.key,
  }) : assert(maxWidth > 0, 'maxWidth must be positive');
  // `tabs` being non-empty and `currentIndex` being inside it are asserted
  // in `_GlassTabBarState.initState` and `didUpdateWidget`, not here: a
  // `List.length` read is not a constant expression, and this constructor
  // stays `const`-constructible.

  /// The selection lens's material when [selectionMaterial] is null.
  ///
  /// Clear glass: no frost, a 10% white tint, a bright rim, a strong colour
  /// split at the edge and a backdrop saturated half as much again. It is
  /// fitted by eye to a liquid_glass_renderer lens of refractive index
  /// 1.15, light intensity 2 and chromatic aberration 0.5. The two
  /// packages split colour by the same rule — red and blue displaced by
  /// `1 ± chromaticAberration / 2` of the refraction — so the 0.5 carries
  /// over as it is. Their refractive indices do not: that package's is a
  /// physical index over a depth it does not scale with the screen, and
  /// this one's [GlassMaterial.edgeRefraction] is pixels of displacement.
  /// The edge refraction here keeps the lens's bend to the bar's in the
  /// same proportion, (1.15 − 1) / (1.21 − 1) of the fitted bar's 27.42
  /// points, about 20.
  static const GlassMaterial defaultSelectionMaterial = GlassMaterial(
    edgeRefraction: 20,
    frost: 0,
    chromaticAberration: 0.5,
    tint: Color(0xFFFFFFFF),
    tintOpacity: 0.1,
    saturation: 1.5,
    highlight: 2,
  );

  /// The destinations, in reading order: left to right, or right to left
  /// under [TextDirection.rtl], where the lens and a drag mirror with them.
  /// Never empty.
  final List<GlassTab> tabs;

  /// The index into [tabs] of the selected destination.
  final int currentIndex;

  /// Called with a tab's index when it is tapped, activated from the
  /// keyboard, or is where a drag was released. Called for the current tab
  /// too when it is tapped again, so a caller can pop to that tab's root —
  /// but not when a drag is released on it.
  final ValueChanged<int> onTap;

  /// What is behind the bar, if the app knows it: the navigationBar role
  /// can flip to the scheme whose labels read better over it.
  final Color? backdrop;

  /// The bar's fill, in place of the role's.
  ///
  /// Null is the navigationBar role's tint colour for the scheme in effect
  /// at its opaque step — `GlassTintStep.opaque`, about 59% white in light
  /// mode and 84% grey in dark. The ramp's steps are solved against the
  /// worst backdrop for each scheme with nothing blurred, which is exactly
  /// what a painted bar is, so that step keeps the role's labels at 7:1 or
  /// better over any photo, and a dimmed tab's label still clears 3:1.
  ///
  /// The labels keep the role's colour whatever is passed here, so a
  /// passed colour is the caller's to check against them. Give it some
  /// transparency to let the backdrop through, as the default does.
  final Color? backgroundColor;

  /// The selection lens's material. Null is [defaultSelectionMaterial].
  ///
  /// The lens is the bar's only glass: it bends the painted bar and the
  /// backdrop showing through it.
  final GlassMaterial? selectionMaterial;

  /// The widest the bar grows, in logical pixels; wider screens centre it.
  ///
  /// Pass [double.infinity] for a bar that spans whatever it is given, less
  /// [margin].
  final double maxWidth;

  /// [maxWidth]'s default: 480 points.
  ///
  /// Wider than any iPhone's bar — the largest, at 440 points across,
  /// lays out a 408-point bar between its margins — so a phone never meets
  /// it. On a tablet or a desktop window it keeps the bar a floating
  /// capsule under the content, rather than a strip whose three to five
  /// tabs sit far apart and far from the thumb, and keeps each tab no wider
  /// than about twice an iPhone's.
  static const double defaultMaxWidth = 480;

  /// The bar's own height, not counting the safe-area inset below it or
  /// the clear space around it — what a layout hard-coding the bar's height
  /// should read instead. The widget as laid out is taller by [margin]'s
  /// vertical total where the safe area asks for less, and by the bottom
  /// safe-area inset where it asks for more.
  ///
  /// It does not change with the text size: tab labels follow the reader's
  /// text scale up to 1.5× and stop there, and a label too long for its
  /// tab ends in an ellipsis.
  static const double height = _barHeight;

  /// The clear space kept between the bar and the screen's edges, where
  /// the safe area asks for less: 16 points either side and 8 below.
  static const EdgeInsets margin = _margin;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

/// The bar's height, not counting the safe-area inset below it.
const double _barHeight = 62;

/// The gap between the bar's edge and the selection inside it.
const double _inset = 6;

/// The most a tab's label grows with the reader's text size.
///
/// The bar keeps one height at every text size, as iOS's tab bar does,
/// which leaves room under a 24-point icon for an 11-point label scaled by
/// about 1.8 at most. iOS itself does not scale tab labels at all, and
/// offers its large-content viewer instead; this package lets them grow a
/// little, to 16.5 points, and no further.
const double _maxLabelScale = 1.5;

/// Clear space kept between the bar and the screen's edges, where the
/// safe area asks for less.
const EdgeInsets _margin = EdgeInsets.fromLTRB(16, 0, 16, 8);

/// The painted pill's alpha over the bar's label colour, on glass only.
const double _pillAlpha = 0.14;

/// The bar's rim: a white hairline, as Kibu draws its painted bar.
const BorderSide _rim = BorderSide(color: Color(0x24FFFFFF));

/// The lens's squash, after Kibu's `_jellyTransform`.
///
/// Measured in alignment units — the lens's position with the first tab
/// at −1 and the last at 1 — as that transform is: the squash is
/// `clamp(speed / 10, 0, 1) × 0.8`, the lens narrows by half of it and
/// grows taller by three tenths of it. At full speed that is 60% of its
/// width and 124% of its height.
const double _jellySpeed = 10;
const double _maxJelly = 0.8;
const double _jellyNarrow = 0.5;
const double _jellyTall = 0.3;

/// An unselected tab's alpha over the bar's label colour.
const double _unlitAlpha = 0.62;

/// A tab's icon size, the gap under it, and its label's size and weights:
/// iOS's own tab-bar metrics.
const double _iconSize = 24;
const double _iconLabelGap = 2;
const double _labelSize = 11;
const FontWeight _litWeight = FontWeight.w600;
const FontWeight _unlitWeight = FontWeight.w500;

/// The longest step the lens's spring takes, in seconds: a quarter of a
/// 60 Hz frame, short enough to stay stable at its stiffness.
const double _substep = 1 / 240;

/// Within these of its target, in tabs and tabs per second, the lens's
/// spring counts as landed.
const double _restDistance = 1e-3;
const double _restVelocity = 1e-2;

/// How far the lens is scaled across and along the bar by [velocity], in
/// tabs per second, on a bar of [tabCount] tabs.
///
/// Kibu's squash is driven by speed in alignment units, where the bar's
/// first tab is −1 and its last is 1, so `tabCount − 1` tabs span 2 units.
/// One tab per second is `2 / (tabCount − 1)` units per second.
({double x, double y}) _squash(double velocity, int tabCount) {
  if (tabCount < 2 || velocity == 0) {
    return (x: 1, y: 1);
  }
  final speed = velocity.abs() * 2 / (tabCount - 1);
  final jelly = (speed / _jellySpeed).clamp(0.0, 1.0) * _maxJelly;
  return (x: 1 - jelly * _jellyNarrow, y: 1 + jelly * _jellyTall);
}

class _GlassTabBarState extends State<GlassTabBar>
    with SingleTickerProviderStateMixin, ReduceMotionSnap {
  late final _Lens _lens;

  /// The tab under the finger while dragging, lit before it is committed.
  int? _hover;

  /// One tab's width, from the most recent layout, for the drag handlers.
  double _slot = 0;

  /// The bar's width, from the most recent layout, for the drag handlers.
  double _width = 0;

  /// Whether the tabs run right to left, from the most recent build, for
  /// the drag handlers: the `Row` puts tab 0 on the right under
  /// [TextDirection.rtl], so a finger is measured from that edge.
  bool _rtl = false;

  int get _last => widget.tabs.length - 1;

  bool get _reduceMotion => GlassReduceMotion.instance.value;

  @override
  void initState() {
    super.initState();
    _assertIndex();
    _lens = _Lens(this, widget.currentIndex.toDouble());
  }

  @override
  void didUpdateWidget(GlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _assertIndex();
    _followIndex();
  }

  /// Aims the lens at [GlassTabBar.currentIndex] unless a drag owns it or
  /// it is already heading there.
  void _followIndex() {
    if (_hover == null && _lens.target != widget.currentIndex) {
      _aim(widget.currentIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _lens.dispose();
    super.dispose();
  }

  void _assertIndex() {
    assert(widget.tabs.isNotEmpty, 'GlassTabBar.tabs must not be empty');
    assert(
      widget.currentIndex >= 0 && widget.currentIndex < widget.tabs.length,
      'GlassTabBar.currentIndex must index into tabs',
    );
  }

  @override
  void didChangeReduceMotion({required bool reduceMotion}) {
    if (reduceMotion) {
      // Turned on mid-flight: land now rather than freeze half way.
      _lens.jump(_lens.target);
    }
    setState(() {});
  }

  void _aim(double target) {
    if (_reduceMotion) {
      _lens.jump(target);
      return;
    }
    final motion = GlassTheme.motionOf(context, GlassMotionRole.settle);
    _lens.aim(target, motion.spring);
  }

  /// How far the finger at [dx] is from the edge tab 0 sits on, inside
  /// the selection's inset.
  double _fromStart(double dx) => (_rtl ? _width - dx : dx) - _inset;

  void _onDrag(double dx) {
    if (_slot <= 0) {
      return;
    }
    final along = _fromStart(dx);
    // The lens centred on the finger, and no further than the end tabs.
    _aim((along / _slot - 0.5).clamp(0, _last.toDouble()));
    final hover = (along / _slot).floor().clamp(0, _last);
    if (hover != _hover) {
      if (_hover != null) {
        unawaited(HapticFeedback.selectionClick());
      }
      setState(() => _hover = hover);
    }
  }

  /// Whether the pointer driving the drag was cancelled rather than lifted:
  /// the drag recognizer ends an accepted drag either way, and only a lift
  /// commits.
  bool _pointerCancelled = false;

  void _onDragEnd() {
    final hover = _hover;
    if (hover == null) {
      return;
    }
    if (_pointerCancelled) {
      _onDragCancel();
      return;
    }
    setState(() => _hover = null);
    _aim(hover.toDouble());
    if (hover == widget.currentIndex) {
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    widget.onTap(hover);
    // An owner that declined [hover], or has not rebuilt with it yet, left
    // [GlassTabBar.currentIndex] where it was: send the lens back there.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) {
          _followIndex();
        }
      })
      ..ensureVisualUpdate();
  }

  void _onDragCancel() {
    setState(() => _hover = null);
    _aim(widget.currentIndex.toDouble());
  }

  /// Whether [_debugCheckTabWidth] has already reported this bar.
  bool _debugReportedNarrowTabs = false;

  /// Reports, once, a bar too narrow to give every tab the 44-point hit
  /// target every control in this package promises.
  ///
  /// Each tab gets an equal share of the bar, and that share cannot grow
  /// past it, so with too many tabs for the width the minimum silently
  /// fails. iOS shows at most five tabs, and a sixth goes behind a "More"
  /// tab; this bar does not do that for you. Reported rather than asserted,
  /// the way an overflowing `Row` is: the bar still lays out.
  void _debugCheckTabWidth() {
    if (_debugReportedNarrowTabs || _slot >= GlassControlFrame.minimumExtent) {
      return;
    }
    _debugReportedNarrowTabs = true;
    final fits = ((_width - 2 * _inset) / GlassControlFrame.minimumExtent)
        .floor();
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FlutterError(
          'GlassTabBar gives each of its ${widget.tabs.length} tabs '
          '${_slot.toStringAsFixed(1)} pt, under the 44 pt minimum hit '
          'target.\n'
          'At ${_width.toStringAsFixed(0)} pt wide the bar fits $fits tabs. '
          'iOS shows at most five, with the rest behind a "More" tab.',
        ),
        library: 'glass_forge',
      ),
    );
  }

  void _onTabActivated(int index) {
    unawaited(HapticFeedback.selectionClick());
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    _rtl = Directionality.of(context) == TextDirection.rtl;
    return SafeArea(
      top: false,
      minimum: _margin,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: SizedBox(
            height: _barHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                _width = width;
                _slot = (width - 2 * _inset) / widget.tabs.length;
                if (kDebugMode) {
                  _debugCheckTabWidth();
                }
                return _bar(context, Size(width, _barHeight));
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, Size size) {
    final onGlass = GlassHostScope.isOnGlass(context);
    final bar = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.navigationBar,
      size: size,
      backdrop: widget.backdrop,
    );
    final lensSize = Size(_slot, _barHeight - 2 * _inset);
    final lensShape = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.control,
      size: lensSize,
      backdrop: widget.backdrop,
    ).shape;
    final lit = _hover ?? widget.currentIndex;
    final ramp = GlassTheme.of(context).tokens.tint.of(bar.brightness);
    final fill =
        widget.backgroundColor ??
        ramp.color.withValues(alpha: ramp.opacityFor(GlassTintStep.opaque));
    final border = bar.shape.toBorder(size);

    // Painted, never glass: no blur and no backdrop read, so the lens over
    // it is the bar's only backdrop pass.
    Widget body = CustomPaint(
      painter: GlassShadowPainter(shape: bar.shape, shadows: bar.shadows),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: border is OutlinedBorder
              ? border.copyWith(side: _rim)
              : border,
        ),
        child: Stack(
          children: [
            // On glass already, the selection paints too.
            if (onGlass)
              _Selection(
                lens: _lens,
                slot: _slot,
                size: lensSize,
                tabCount: widget.tabs.length,
                child: ClipPath(
                  clipper: GlassShapeClipper(lensShape),
                  child: ColoredBox(
                    color: bar.labelColor.withValues(alpha: _pillAlpha),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(_inset),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < widget.tabs.length; i++)
                    Expanded(
                      child: _TabButton(
                        tab: widget.tabs[i],
                        lit: i == lit,
                        selected: i == widget.currentIndex,
                        color: bar.labelColor,
                        onActivate: () => _onTabActivated(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // Presence reaches only glass, so the painted bar fades with it here.
    final presence = GlassPresenceScope.maybeOf(context);
    if (presence != null) {
      body = FadeTransition(opacity: presence, child: body);
    }

    // The listener sees a pointer's cancel before the drag recognizer turns
    // it into an end: see [_pointerCancelled].
    return Listener(
      onPointerDown: (_) => _pointerCancelled = false,
      onPointerCancel: (_) => _pointerCancelled = true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // `down`, not `start`: the slop a drag must clear before `start`
        // reports anything would otherwise be dropped from the lens's travel
        // rather than merely delayed.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (d) => _onDrag(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => _onDrag(d.localPosition.dx),
        onHorizontalDragEnd: (_) => _onDragEnd(),
        onHorizontalDragCancel: _onDragCancel,
        child: Stack(
          children: [
            Positioned.fill(child: body),
            // Over the painted bar and its labels, bending both. It takes
            // no pointers: the tabs and the drag under it do. It fades with
            // the enclosing presence, as all glass does.
            if (!onGlass)
              _Selection(
                lens: _lens,
                slot: _slot,
                size: lensSize,
                tabCount: widget.tabs.length,
                child: IgnorePointer(
                  child: Glass(
                    shape: lensShape,
                    material:
                        widget.selectionMaterial ??
                        GlassTabBar.defaultSelectionMaterial,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The selection, positioned at the lens's place in the bar and squashed
/// by its speed.
///
/// A [Transform], which the glass under it follows: the layer reads each
/// shape's transform when it paints.
class _Selection extends StatelessWidget {
  const _Selection({
    required this.lens,
    required this.slot,
    required this.size,
    required this.tabCount,
    required this.child,
  });

  /// Where the lens is, in tabs, and how fast it is going.
  final _Lens lens;

  /// One tab's width.
  final double slot;

  /// The lens's size at rest.
  final Size size;

  /// How many tabs the bar has, for the squash's units.
  final int tabCount;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: lens,
      child: child,
      builder: (context, child) {
        final squash = _squash(lens.velocity, tabCount);
        return PositionedDirectional(
          start: _inset + lens.position * slot,
          top: _inset,
          width: size.width,
          height: size.height,
          child: Transform.scale(
            scaleX: squash.x,
            scaleY: squash.y,
            child: child,
          ),
        );
      },
    );
  }
}

/// One tab: its icon over its label, as a selectable button.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.lit,
    required this.selected,
    required this.color,
    required this.onActivate,
  });

  final GlassTab tab;

  /// Drawn as selected: the current tab, or the one under a dragging
  /// finger.
  final bool lit;

  /// Reported to a screen reader as selected: only the current tab.
  final bool selected;

  /// The bar's label colour.
  final Color color;

  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final tint = lit ? color : color.withValues(alpha: _unlitAlpha);
    return GlassControlFrame(
      onActivate: onActivate,
      selected: selected,
      semanticLabel: tab.semanticLabel ?? tab.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme.merge(
            data: IconThemeData(color: tint, size: _iconSize),
            child: lit ? tab.activeIcon ?? tab.icon : tab.icon,
          ),
          const SizedBox(height: _iconLabelGap),
          // Scaled with the reader's text size only up to [_maxLabelScale]:
          // the bar is a fixed height, and past that the label no longer
          // fits under the icon. A long label is cut short with an
          // ellipsis rather than wrapped.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: _maxLabelScale,
            child: Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tint,
                fontSize: _labelSize,
                fontWeight: lit ? _litWeight : _unlitWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The selection's position, in tabs, moved by a spring stepped every
/// frame.
///
/// Not an [AnimationController] running a `SpringSimulation`: a drag
/// re-aims the spring on every pointer event, and restarting a simulation
/// restarts its clock, so a finger moving each frame would hold the lens
/// frozen where it started. Stepping one spring toward a moving target
/// keeps its position and speed through any number of re-aims.
class _Lens extends ChangeNotifier {
  _Lens(TickerProvider vsync, double at) : position = at, target = at {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// The spring [aim] last set. The ticker only ever starts from [aim],
  /// so it is always assigned before [_tick] reads it.
  late SpringDescription _spring;

  /// Where the selection is, in tabs.
  double position;

  /// How fast it is going, in tabs per second.
  double velocity = 0;

  /// Where it is heading, in tabs.
  double target;

  /// Sends it toward [to] on [spring], keeping its current speed.
  void aim(double to, SpringDescription spring) {
    target = to;
    _spring = spring;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
      notifyListeners();
    }
  }

  /// Puts it at [to] at once.
  void jump(double to) {
    _ticker.stop();
    position = target = to;
    velocity = 0;
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // A long frame is stepped in small pieces, or the spring explodes.
    while (dt > 0) {
      final h = math.min(dt, _substep);
      final force =
          -_spring.stiffness * (position - target) - _spring.damping * velocity;
      velocity += force / _spring.mass * h;
      position += velocity * h;
      dt -= h;
    }
    if ((position - target).abs() < _restDistance &&
        velocity.abs() < _restVelocity) {
      position = target;
      velocity = 0;
      _ticker.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
