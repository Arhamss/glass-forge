import 'dart:async';

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
/// and the photo beneath it. When it moves it swells a little past the
/// bar's edges as it slides and settles back as it lands — iOS 26's tab
/// bar. The lens is its own backdrop pass, and it shares the bar's
/// presence, so it goes when the bar does.
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

class _GlassTabBarState extends State<GlassTabBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  /// Up fast, held while it travels, then settling back into the capsule.
  late final Animation<double> _lens = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 20,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 45),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 35,
    ),
  ]).animate(_flight);

  @override
  void didUpdateWidget(GlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected && !reduceMotion(context)) {
      _flight.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    final x = -1 + 2 * widget.selected / (tabs.length - 1);
    final slide = motion(context, const Duration(milliseconds: 520));
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedAlign(
                      alignment: Alignment(x, 0),
                      duration: slide,
                      curve: settle,
                      child: FractionallySizedBox(
                        widthFactor: 1 / tabs.length,
                        heightFactor: 1,
                        child: _Selection(
                          swell: _lens,
                          presence: widget.presence,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: _Tab(
                              tab: tabs[i],
                              selected: i == widget.selected,
                              onTap: () {
                                unawaited(HapticFeedback.selectionClick());
                                widget.onSelected(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The glass lens under the selected tab, swelling while it travels.
class _Selection extends StatelessWidget {
  const _Selection({required this.swell, required this.presence});

  /// 0 at rest, 1 mid-flight.
  final Animation<double> swell;

  /// The bar's presence. Held by identity: it drives one backdrop pass.
  final Animation<double> presence;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: swell,
      child: GlassPresence(
        presence: presence,
        child: const Glass(
          material: selectionMaterial,
          shape: GlassRoundedRectangle(
            radius: BorderRadius.all(Radius.circular(25)),
          ),
        ),
      ),
      // Swells past the bar while it travels: a lens standing proud of the
      // surface it slides along.
      builder: (context, child) {
        final t = swell.value;
        return Transform.scale(
          scaleX: 1 + 0.16 * t,
          scaleY: 1 + 0.34 * t,
          child: child,
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
