import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/glyphs.dart';
import 'package:glass_forge_example/src/presets.dart';
import 'package:glass_forge_example/src/ui.dart';

class SceneTab {
  const SceneTab(this.label, this.icon);

  final String label;
  final String icon;
}

/// A floating capsule of tabs whose selection is a lens of glass.
///
/// The selection is a clear glass lens sitting in the bar, bending the bar
/// and the photo beneath it. One spring moves it, and everything else is
/// read off that spring: a tap aims it at the new tab, a drag keeps
/// re-aiming it at the finger — so it chases rather than sticks, and keeps
/// its momentum through a change of mind — and a release aims it at the
/// tab it was thrown towards. As it moves it squashes along its travel and
/// bulges across it, by its own speed, so shape and motion are one thing;
/// held, it lifts a little proud of the bar. The lens is its own backdrop
/// pass, and it shares the bar's presence, so it goes when the bar does.
class GlassTabBar extends StatefulWidget {
  const GlassTabBar({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    required this.presence,
    super.key,
  });

  static const double height = 62;

  final List<SceneTab> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  /// How present the bar is. Drives the glass through [GlassPresence] and
  /// the labels through a fade: presence reaches only the refraction, and
  /// labels left behind on vanished glass would float over the sheet.
  final Animation<double> presence;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

/// SwiftUI's `.bouncy`: half a second, 30% bounce. It overshoots its tab
/// visibly and rings once, which is what makes the lens read as liquid
/// rather than slid. The same spring chases the finger during a drag.
const _Spring _bouncy = _Spring(duration: 0.5, bounce: 0.3);

/// A spring given the way SwiftUI gives one: how long it takes, and how
/// far past its target it swings.
class _Spring {
  const _Spring({required this.duration, required this.bounce});

  /// Seconds.
  final double duration;

  /// 0 is critically damped; 0.3 overshoots by about a third.
  final double bounce;

  double get stiffness => math.pow(2 * math.pi / duration, 2).toDouble();

  double get damping => 4 * math.pi * (1 - bounce) / duration;
}

/// The lens's position, in tabs, moved by a spring stepped every frame.
///
/// Not an [AnimationController] running a `SpringSimulation`: a drag
/// re-aims the spring on every pointer event, and restarting a simulation
/// restarts its clock, so a finger moving each frame would hold the lens
/// frozen where it started. Stepping one spring toward a moving target
/// keeps its position and speed through any number of re-aims.
class _Lens extends ChangeNotifier {
  _Lens(TickerProvider vsync, double at) : position = at, _target = at {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  double position;
  double velocity = 0;
  double _target;
  _Spring _spring = _bouncy;

  void aim(double target, _Spring spring) {
    _target = target;
    _spring = spring;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void jump(double to) {
    _ticker.stop();
    position = _target = to;
    velocity = 0;
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // A dropped frame is stepped in small pieces, or the spring explodes.
    while (dt > 0) {
      final h = math.min(dt, 1 / 240);
      final force =
          -_spring.stiffness * (position - _target) -
          _spring.damping * velocity;
      velocity += force * h;
      position += velocity * h;
      dt -= h;
    }
    if ((position - _target).abs() < 1e-3 && velocity.abs() < 1e-2) {
      position = _target;
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

class _GlassTabBarState extends State<GlassTabBar>
    with TickerProviderStateMixin {
  late final _Lens _lens = _Lens(this, widget.selected.toDouble());

  /// 1 while a finger holds the lens.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 360),
  );

  /// The tab under the finger while dragging, lit before it is committed.
  int? _hover;

  /// Where the finger is, in tabs, while dragging.
  double _finger = 0;

  int get _last => widget.tabs.length - 1;

  @override
  void didUpdateWidget(GlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected && _hover == null) {
      _aim(widget.selected.toDouble(), _bouncy);
    }
  }

  void _aim(double target, _Spring spring) {
    if (reduceMotion(context)) {
      _lens.jump(target);
    } else {
      _lens.aim(target, spring);
    }
  }

  void _onDragStart(DragStartDetails details, double slot) {
    _hold.forward();
    _onDrag(details.localPosition.dx, slot);
  }

  void _onDrag(double dx, double slot) {
    // The finger in tabs, allowed a little past either end.
    _finger = (dx / slot - 0.5).clamp(-0.2, _last + 0.2);
    _aim(_finger, _bouncy);
    final hover = _finger.round().clamp(0, _last);
    if (hover != _hover) {
      if (_hover != null) unawaited(HapticFeedback.selectionClick());
      setState(() => _hover = hover);
    }
  }

  void _onDragEnd(DragEndDetails details, double slot) {
    // Where a throw would carry it, so a flick lands a tab further on.
    final fling = details.velocity.pixelsPerSecond.dx / slot;
    _release((_finger + fling * 0.08).round().clamp(0, _last));
  }

  void _release(int target) {
    _hold.reverse();
    setState(() => _hover = null);
    _aim(target.toDouble(), _bouncy);
    if (target != widget.selected) {
      unawaited(HapticFeedback.lightImpact());
      widget.onSelected(target);
    }
  }

  @override
  void dispose() {
    _lens.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    final lit = _hover ?? widget.selected;
    return SizedBox(
      height: GlassTabBar.height,
      width: 92.0 * tabs.length + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GlassPresence(
              presence: widget.presence,
              child: const Glass(
                material: chromeMaterial,
                shape: GlassRoundedRectangle(
                  radius: BorderRadius.all(
                    Radius.circular(GlassTabBar.height / 2),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FadeTransition(
              opacity: widget.presence,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slot = constraints.maxWidth / tabs.length;
                    // A raw listener, not a tap handler: it lifts the lens
                    // on any press without joining the gesture arena the
                    // tabs and the drag compete in.
                    return Listener(
                      onPointerDown: (_) => _hold.forward(),
                      onPointerUp: (_) => _hold.reverse(),
                      onPointerCancel: (_) => _hold.reverse(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (d) => _onDragStart(d, slot),
                        onHorizontalDragUpdate: (d) =>
                            _onDrag(d.localPosition.dx, slot),
                        onHorizontalDragEnd: (d) => _onDragEnd(d, slot),
                        onHorizontalDragCancel: () => _release(widget.selected),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _Selection(
                              lens: _lens,
                              hold: _hold,
                              slot: slot,
                              presence: widget.presence,
                            ),
                            Row(
                              children: [
                                for (var i = 0; i < tabs.length; i++)
                                  Expanded(
                                    child: _Tab(
                                      tab: tabs[i],
                                      selected: i == lit,
                                      onTap: () {
                                        unawaited(
                                          HapticFeedback.selectionClick(),
                                        );
                                        widget.onSelected(i);
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The glass lens under the selected tab.
class _Selection extends StatelessWidget {
  const _Selection({
    required this.lens,
    required this.hold,
    required this.slot,
    required this.presence,
  });

  /// Where the lens is, in tabs, and how fast it is going.
  final _Lens lens;

  /// 1 while a finger holds the lens.
  final Animation<double> hold;

  /// One tab's width.
  final double slot;

  /// The bar's presence. Held by identity: it drives one backdrop pass.
  final Animation<double> presence;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([lens, hold]),
      child: GlassPresence(
        presence: presence,
        // No material of its own: it wears the layer's, which is whatever
        // the tuner has picked, and morphs with it. It still gets a pass of
        // its own — passes are keyed by presence driver too, and this one
        // is the bar's — so it never takes one of a scene's shape slots.
        child: const Glass(
          shape: GlassRoundedRectangle(
            radius: BorderRadius.all(Radius.circular(25)),
          ),
        ),
      ),
      builder: (context, child) {
        final speed = lens.velocity.abs();
        // Lift: the lens swells up out of the bar whenever it is pressed or
        // moving — iOS 26's lens — so every touch visibly picks it up.
        final lift =
            1 +
            0.32 *
                math.max(
                  Curves.easeOut.transform(hold.value),
                  1 - math.exp(-speed / 2.5),
                );
        // Jelly, as Kibu's lens does it: squashed along its travel and
        // bulging across it, by speed — tabs per second, saturating at 10.
        final jelly = (speed / 10).clamp(0.0, 1.0) * 0.8;
        return Positioned(
          left: lens.position * slot,
          top: 0,
          bottom: 0,
          width: slot,
          child: Transform.scale(
            scaleX: lift * (1 - jelly * 0.3),
            scaleY: lift * (1 + jelly * 0.3),
            child: child,
          ),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.selected, required this.onTap});

  final SceneTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, const Duration(milliseconds: 260));
    final color = selected ? Tone.primary : Tone.tertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: duration,
              curve: Curves.easeOutBack,
              child: Glyph(tab.icon, size: 22, color: color),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: duration,
              style: Font.body.copyWith(fontSize: 11, color: color),
              child: Text(tab.label),
            ),
          ],
        ),
      ),
    );
  }
}
