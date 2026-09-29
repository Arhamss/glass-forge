import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_surface.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';
import 'package:glass_forge/src/motion/settle_spring.dart';
import 'package:glass_forge/src/rendering/declared_glass_handoff.dart';
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

/// A floating glass capsule of tabs whose selection turns to glass while it
/// moves.
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
/// The bar is a [GlassSurface.navigationBar] with the bottom safe-area
/// inset built in. The selection is a painted pill at rest — it sits on the
/// bar's glass, and glass on glass is the stacked backdrop filter this
/// package exists to avoid (flutter#187820). While the selection travels,
/// and only then, a glass lens in a material of its own rises out of the
/// pill through a [GlassPresence], swelling a little past the bar's edges,
/// and fades back into the pill as it lands. A finger resting on the bar
/// without moving swells the painted pill instead, and the lens sinks
/// within 280 ms of the selection catching up with a finger that stops
/// mid-drag. At rest the lens's presence is 0, which drops its backdrop
/// pass entirely: the bar is the only glass there. The lens is the one
/// place this package puts glass over glass, as a bounded handoff, and it
/// is exempt from the layer's debug overlap warning for that reason.
///
/// One spring — the theme's [GlassMotionRole.settle] — moves the selection.
/// A tap aims it at the new tab. A drag anywhere along the bar keeps
/// re-aiming it at the finger, so it chases rather than sticks, and a
/// release throws it to the tab it was heading for, carrying the finger's
/// speed. Nothing is reported until the finger lifts. The selection always
/// ends up at [currentIndex]: an owner that declines the tab a drag was
/// released on, or has not rebuilt with it by the next frame, gets the
/// selection sent back, and only the tab at [currentIndex] ever reports
/// itself selected.
///
/// The lens shares the bar's presence: its own is the bar's times its
/// flight, so a bar faded out by a covering route never leaves a lens
/// behind. Presence only reaches glass, so the bar fades its own painted
/// labels, icons and pill with it too.
///
/// Under Reduce Motion there is no lens at all and the pill moves
/// instantly.
///
/// The arrow keys move keyboard focus from tab to tab, through the app's
/// ordinary directional focus traversal; Enter or Space then selects the
/// focused tab. They do not change the selection themselves, because
/// selecting a tab navigates.
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
    this.material,
    super.key,
  });
  // `tabs` being non-empty and `currentIndex` being inside it are asserted
  // in `_GlassTabBarState.initState` and `didUpdateWidget`, not here: a
  // `List.length` read is not a constant expression, and this constructor
  // stays `const`-constructible.

  /// The destinations, in reading order: left to right, or right to left
  /// under [TextDirection.rtl], where the pill, the lens and a drag mirror
  /// with them. Never empty.
  final List<GlassTab> tabs;

  /// The index into [tabs] of the selected destination.
  final int currentIndex;

  /// Called with a tab's index when it is tapped, activated from the
  /// keyboard, or is where a drag was released. Called for the current tab
  /// too when it is tapped again, so a caller can pop to that tab's root.
  final ValueChanged<int> onTap;

  /// What is behind the bar, for the adaptation `GlassSurface` offers.
  final Color? backdrop;

  /// The bar's material, in place of the one the navigationBar role
  /// resolves to.
  ///
  /// Null keeps the role's — Apple's fitted regular material at the role's
  /// blur and tint steps, which is right for a bar of app chrome. An app
  /// with a look of its own names one here; the label colour and motion
  /// still come from the role.
  final GlassMaterial? material;

  /// The bar's total height, not counting the safe-area inset below it —
  /// what a layout hard-coding the bar's height should read instead.
  ///
  /// It does not change with the text size: tab labels follow the reader's
  /// text scale up to 1.5× and stop there, and a label too long for its
  /// tab ends in an ellipsis.
  static const double height = _barHeight;

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

/// How quickly the lens rises out of the pill when the selection starts to
/// move, and how quickly it sinks back once it lands.
const Duration _rise = Duration(milliseconds: 160);
const Duration _sink = Duration(milliseconds: 280);

/// How long a finger's press takes to swell the painted pill (and, while
/// the selection is travelling, the lens already up), and to let it go.
const Duration _holdIn = Duration(milliseconds: 200);
const Duration _holdOut = Duration(milliseconds: 360);

/// How far the lens swells past its slot, at most: a 50-point lens reaches
/// 66, a little past the 62-point bar.
const double _maxSwell = 0.32;

/// How far past the first or last tab a dragging finger may pull the
/// selection, in tabs: a little give at either end, not a hard stop.
const double _fingerOvershoot = 0.2;

/// The painted pill's alpha over the bar's label colour.
const double _pillAlpha = 0.14;

/// The speed, in tabs per second, at which the lens has swollen about
/// two-thirds of the way ([_maxSwell] × (1 − 1/e)).
const double _swellSpeed = 2.5;

/// The speed, in tabs per second, at which the lens's jelly squash is at
/// its most, and how far that squashes it: up to 24% narrower and 24%
/// taller.
const double _jellySpeed = 10;
const double _maxJelly = 0.24;

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

/// How far a release carries the selection per tab-per-second of throw.
const double _throw = 0.08;

class _GlassTabBarState extends State<GlassTabBar>
    with TickerProviderStateMixin, ReduceMotionSnap {
  late final _Lens _lens;

  /// 1 while a finger is down on the bar.
  late final AnimationController _hold;

  /// 1 while the lens is up, which is only while the selection is moving;
  /// a still finger never raises it. See [_syncFlight].
  late final AnimationController _flight;

  /// The bar's presence, from the enclosing [GlassPresence] — a
  /// `GlassScaffold`'s, usually — or [_ownPresence] without one.
  late Animation<double> _barPresence;

  /// Full presence, as an object of this bar's own.
  ///
  /// The bar's glass always carries a presence whose identity is this
  /// bar's, so the lens can declare it hands off over exactly that glass
  /// (see [DeclaredGlassHandoff]). Without one, the bar's glass and any
  /// other glass in the layer with no presence would look the same to the
  /// overlap check, and the lens would be exempt against all of them.
  final Animation<double> _ownPresence = _FullPresence();

  /// The lens's presence: the bar's, times [_flight]. Rebuilt only when the
  /// bar's presence object changes, because [GlassPresence] holds its
  /// animation by identity and a fresh one is a fresh backdrop pass.
  late Animation<double> _lensPresence;

  /// What moves the painted pill, and what moves the lens: merged once
  /// here, not in `build`, where every rebuild would have its
  /// `AnimatedBuilder` unsubscribe and resubscribe.
  late final Listenable _pillMotion = Listenable.merge([_lens, _flight, _hold]);
  late final Listenable _lensMotion = Listenable.merge([_lens, _hold]);

  /// Whether a finger is down on the bar.
  bool _pressed = false;

  /// The tab under the finger while dragging, lit before it is committed.
  int? _hover;

  /// Where the finger is, in tabs, while dragging.
  double _finger = 0;

  /// One tab's width, from the most recent layout, for the drag handlers.
  double _slot = 0;

  /// The bar's width, from the most recent layout, for the drag handlers.
  double _width = 0;

  /// Whether the tabs run right to left, from the most recent build, for
  /// the drag handlers: the `Row` puts tab 0 on the right under
  /// [TextDirection.rtl], so a finger is measured from that edge.
  bool _rtl = false;

  /// Whether the bar is on glass already — inside a sheet, say — from the
  /// most recent build. There the bar paints (see `GlassSurface`) and has
  /// no lens: the painted pill carries the selection and springs to it,
  /// and nothing here is glass.
  bool _onGlass = false;

  int get _last => widget.tabs.length - 1;

  bool get _reduceMotion => GlassReduceMotion.instance.value;

  @override
  void initState() {
    super.initState();
    _assertIndex();
    _lens = _Lens(this, widget.currentIndex.toDouble())
      ..addListener(_syncFlight);
    _hold = AnimationController(
      vsync: this,
      duration: _holdIn,
      reverseDuration: _holdOut,
    );
    _flight = AnimationController(
      vsync: this,
      duration: _rise,
      reverseDuration: _sink,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bar = GlassPresenceScope.maybeOf(context) ?? _ownPresence;
    if (!_lensPresenceBuilt || !identical(bar, _barPresence)) {
      _lensPresenceBuilt = true;
      _barPresence = bar;
      _lensPresence = _Product(bar, _flight, handsOffWith: bar);
    }
  }

  bool _lensPresenceBuilt = false;

  @override
  void didUpdateWidget(GlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _assertIndex();
    _followIndex();
  }

  /// Aims the selection at [GlassTabBar.currentIndex] unless a drag owns it
  /// or it is already heading there.
  void _followIndex() {
    if (_hover == null && _lens.target != widget.currentIndex) {
      _aim(widget.currentIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _lens.dispose();
    _hold.dispose();
    _flight.dispose();
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
      _lens.jump(_hover?.toDouble() ?? widget.currentIndex.toDouble());
      _hold.value = 0;
      _flight.value = 0;
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

  /// Raises the lens while the selection is travelling, and lets it sink
  /// once it has caught up with its target.
  ///
  /// Only travel, never a press: the lens is a second backdrop pass over
  /// the bar's (flutter#187820), declared as a bounded handoff (see
  /// [_Product]), and a finger resting on the bar has no bound. A still
  /// finger, before or during a drag, shows the painted pill swelling
  /// under it instead; the lens sinks within [_sink] of the spring
  /// settling on the finger.
  void _syncFlight() {
    if (_reduceMotion || _onGlass) {
      return;
    }
    final up = _lens.isMoving;
    final status = _flight.status;
    if (up) {
      if (status != AnimationStatus.forward &&
          status != AnimationStatus.completed) {
        _flight.forward();
      }
    } else if (status != AnimationStatus.reverse &&
        status != AnimationStatus.dismissed) {
      _flight.reverse();
    }
  }

  void _press(bool down) {
    if (_pressed == down) {
      return;
    }
    _pressed = down;
    if (!_reduceMotion) {
      unawaited(down ? _hold.forward() : _hold.reverse());
    }
    _syncFlight();
  }

  void _onDragStart(DragStartDetails details) {
    _press(true);
    _onDrag(details.localPosition.dx);
  }

  void _onDrag(double dx) {
    if (_slot <= 0) {
      return;
    }
    // The finger in tabs, allowed a little past either end, measured from
    // the edge tab 0 sits on.
    final fromStart = _rtl ? _width - dx : dx;
    _finger = ((fromStart - _inset) / _slot - 0.5).clamp(
      -_fingerOvershoot,
      _last + _fingerOvershoot,
    );
    _aim(_finger);
    final hover = _finger.round().clamp(0, _last);
    if (hover != _hover) {
      if (_hover != null) {
        unawaited(HapticFeedback.selectionClick());
      }
      setState(() => _hover = hover);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final dx = details.velocity.pixelsPerSecond.dx;
    final fling = _slot > 0 ? (_rtl ? -dx : dx) / _slot : 0.0;
    _release((_finger + fling * _throw).round().clamp(0, _last));
  }

  void _release(int target) {
    setState(() => _hover = null);
    _aim(target.toDouble());
    _press(false);
    if (target != widget.currentIndex) {
      unawaited(HapticFeedback.lightImpact());
      widget.onTap(target);
      // An owner that declined [target], or has not rebuilt with it yet,
      // left [GlassTabBar.currentIndex] where it was: send it back there.
      SchedulerBinding.instance
        ..addPostFrameCallback((_) {
          if (mounted) {
            _followIndex();
          }
        })
        ..ensureVisualUpdate();
    }
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
    _onGlass = GlassHostScope.isOnGlass(context);
    return SafeArea(
      top: false,
      minimum: _margin,
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
    );
  }

  Widget _bar(BuildContext context, Size size) {
    final reduceMotion = _reduceMotion;
    final bar = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.navigationBar,
      size: size,
      backdrop: widget.backdrop,
    );
    final lensSize = Size(_slot, _barHeight - 2 * _inset);
    final lensStyle = GlassTheme.surfaceOf(
      context,
      GlassSurfaceRole.control,
      size: lensSize,
      backdrop: widget.backdrop,
    );
    final lit = _hover ?? widget.currentIndex;

    // The bar's [GlassSurface] fades this with the bar's presence.
    final content = Stack(
      children: [
        AnimatedBuilder(
          animation: _pillMotion,
          builder: (context, child) => PositionedDirectional(
            start: _inset + _lens.position * _slot,
            top: _inset,
            width: lensSize.width,
            height: lensSize.height,
            // A held finger swells the painted pill, never the lens: see
            // [_syncFlight]. Kept inside the bar, a quarter of the lens's
            // swell.
            child: Transform.scale(
              scale: 1 + _maxSwell / 4 * Curves.easeOut.transform(_hold.value),
              child: Opacity(opacity: 1 - _flight.value, child: child),
            ),
          ),
          child: ClipPath(
            clipper: GlassShapeClipper(lensStyle.shape),
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
    );

    return Listener(
      // A raw listener, not a tap handler: it tracks a press, which swells
      // the painted pill, without joining the arena the tabs and the drag
      // compete in. A press alone never raises the lens.
      onPointerDown: (_) => _press(true),
      onPointerUp: (_) {
        if (_hover == null) {
          _press(false);
        }
      },
      onPointerCancel: (_) {
        if (_hover == null) {
          _press(false);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // `down`, not `start`: the slop a drag must clear before `start`
        // reports anything would otherwise be dropped from the lens's
        // travel rather than merely delayed.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: (d) => _onDrag(d.localPosition.dx),
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: () => _release(widget.currentIndex),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              // The bar's glass, under its own presence; see
              // [_ownPresence].
              child: GlassPresenceScope(
                presence: _barPresence,
                child: GlassSurface.navigationBar(
                  backdrop: widget.backdrop,
                  material: widget.material,
                  child: content,
                ),
              ),
            ),
            // A sibling of the bar's glass, never inside it: a `Glass`
            // built in another's child is refused outright.
            if (!reduceMotion && !_onGlass)
              _LensGlass(
                lens: _lens,
                hold: _hold,
                motion: _lensMotion,
                slot: _slot,
                size: lensSize,
                presence: _lensPresence,
                glass: Glass(
                  shape: lensStyle.shape,
                  material: lensStyle.material,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The glass lens, positioned over the selection and swollen by its speed.
///
/// It is only up while the selection travels (see
/// `_GlassTabBarState._syncFlight`). A finger's hold adds to the swell
/// while it is up, but never raises it.
class _LensGlass extends StatelessWidget {
  const _LensGlass({
    required this.motion,
    required this.lens,
    required this.hold,
    required this.slot,
    required this.size,
    required this.presence,
    required this.glass,
  });

  /// Where the lens is, in tabs, and how fast it is going.
  final _Lens lens;

  /// 1 while a finger holds the bar.
  final Animation<double> hold;

  /// [lens] and [hold] merged, once, by the bar's state.
  final Listenable motion;

  /// One tab's width.
  final double slot;

  /// The lens's unswollen size.
  final Size size;

  /// The lens's own presence. Held by identity: it drives one backdrop
  /// pass, separate from the bar's.
  final Animation<double> presence;

  /// The lens's glass.
  final Widget glass;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: motion,
      child: GlassPresence(presence: presence, child: glass),
      builder: (context, child) {
        final speed = lens.velocity.abs();
        // Swells out of the bar with its speed, and with a finger's hold
        // while it is already up. A still press never raises it; the
        // painted pill swells for that instead.
        final swell =
            1 +
            _maxSwell *
                math.max(
                  Curves.easeOut.transform(hold.value),
                  1 - math.exp(-speed / _swellSpeed),
                );
        // Squashed along its travel and bulging across it, by speed in
        // tabs per second, saturating at 10.
        final jelly = (speed / _jellySpeed).clamp(0.0, 1.0) * _maxJelly;
        return PositionedDirectional(
          start: _inset + lens.position * slot,
          top: _inset,
          width: size.width,
          height: size.height,
          child: Transform.scale(
            scaleX: swell * (1 - jelly),
            scaleY: swell * (1 + jelly),
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

/// [first] times [next].
///
/// The lens's presence, and a [DeclaredGlassHandoff]: the lens overlaps the
/// bar's glass on purpose, only while the selection travels (see
/// `_GlassTabBarState._syncFlight`), so the layer's overlap warning leaves
/// it out. Its bound is the settle spring plus the 280 ms sink.
class _Product extends CompoundAnimation<double>
    implements DeclaredGlassHandoff {
  _Product(
    Animation<double> first,
    Animation<double> next, {
    required this.handsOffWith,
  }) : super(first: first, next: next);

  @override
  final Object? handsOffWith;

  @override
  double get value => first.value * next.value;
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

  /// Whether it is still travelling.
  bool get isMoving => _ticker.isActive;

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

/// Full presence, as a distinct object: see
/// `_GlassTabBarState._ownPresence`.
class _FullPresence extends AlwaysStoppedAnimation<double> {
  _FullPresence() : super(1);
}
