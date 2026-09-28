import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/glyphs.dart';
import 'package:glass_forge_example/src/playground.dart';
import 'package:glass_forge_example/src/ui.dart';

/// The same glass as real interface, laid out like Control Center: pill
/// tiles with an icon well, round toggles, a media tile and two sliders —
/// all of it tuned live by the sheet below.
///
/// Nothing here is glass inside glass. The wells, tracks and buttons that
/// sit *on* a tile are painted — two shapes in one pass would just union
/// into one outline, and a second pass over the first is the stacking
/// Apple tells you not to do.
class KitScene extends StatelessWidget {
  const KitScene({super.key});

  static const double _gap = 12;
  static const double _tile = 64;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Arrive(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _PillToggle(
                        icon: Glyphs.wifi,
                        title: 'Wi-Fi',
                        on: 'Glass Forge 5G',
                        initial: true,
                      ),
                      SizedBox(height: _gap),
                      _PillToggle(
                        icon: Glyphs.bluetooth,
                        title: 'Bluetooth',
                        on: 'On',
                      ),
                    ],
                  ),
                ),
                SizedBox(width: _gap),
                SizedBox(
                  width: 128,
                  height: _tile * 2 + _gap,
                  child: _NowPlaying(),
                ),
              ],
            ),
          ),
          SizedBox(height: _gap),
          Arrive(
            delay: Duration(milliseconds: 60),
            child: Row(
              children: [
                _RoundToggle(icon: Glyphs.contrast, label: 'Dark mode'),
                SizedBox(width: _gap),
                _RoundToggle(
                  icon: Glyphs.rotate,
                  label: 'Rotation lock',
                  initial: true,
                ),
                SizedBox(width: _gap),
                Expanded(
                  child: _PillToggle(
                    icon: Glyphs.moon,
                    title: 'Focus',
                    on: 'Do Not Disturb',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _gap),
          Arrive(
            delay: Duration(milliseconds: 120),
            child: _SliderTile(
              title: 'Display',
              low: Glyphs.sun,
              high: Glyphs.sunBold,
              initial: 0.55,
            ),
          ),
          SizedBox(height: _gap),
          Arrive(
            delay: Duration(milliseconds: 180),
            child: _SliderTile(
              title: 'Sound',
              low: Glyphs.volumeLow,
              high: Glyphs.volumeHigh,
              initial: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiles give a little under the finger rather than reaching for it: the
/// default press-stretch is sized for a 44 pt button.
const GlassPressStretch _tileStretch = GlassPressStretch(
  intensity: 0.06,
  travel: 0.03,
);

const GlassShape _pill = GlassRoundedRectangle(
  radius: BorderRadius.all(Radius.circular(KitScene._tile / 2)),
);

/// A painted circle behind an icon: white with the icon in blue when on,
/// a faint wash when off.
class _Well extends StatelessWidget {
  const _Well({required this.icon, required this.on});

  final String icon;
  final bool on;

  static const double _size = 44;
  static const Color _blue = Color(0xFF0A84FF);

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, const Duration(milliseconds: 280));
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? const Color(0xFFFFFFFF) : const Color(0x24FFFFFF),
      ),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: on ? _blue : Tone.primary),
        duration: duration,
        builder: (context, color, _) =>
            Glyph(icon, size: _size * 0.5, color: color),
      ),
    );
  }
}

class _PillToggle extends StatefulWidget {
  const _PillToggle({
    required this.icon,
    required this.title,
    required this.on,
    this.initial = false,
  });

  final String icon;
  final String title;
  final String on;
  final bool initial;

  @override
  State<_PillToggle> createState() => _PillToggleState();
}

class _PillToggleState extends State<_PillToggle> {
  late bool _on = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: _on,
      label: widget.title,
      excludeSemantics: true,
      child: InteractiveGlass(
        pressScale: 0.97,
        pressStretch: _tileStretch,
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          setState(() => _on = !_on);
        },
        child: SizedBox(
          height: KitScene._tile,
          child: Glass(
            shape: _pill,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  _Well(icon: widget.icon, on: _on),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Font.title.copyWith(fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        AnimatedSwitcher(
                          duration: motion(
                            context,
                            const Duration(milliseconds: 200),
                          ),
                          child: Text(
                            _on ? widget.on : 'Off',
                            key: ValueKey(_on),
                            style: Font.body.copyWith(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundToggle extends StatefulWidget {
  const _RoundToggle({
    required this.icon,
    required this.label,
    this.initial = false,
  });

  final String icon;
  final String label;
  final bool initial;

  @override
  State<_RoundToggle> createState() => _RoundToggleState();
}

class _RoundToggleState extends State<_RoundToggle> {
  late bool _on = widget.initial;

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, const Duration(milliseconds: 320));
    return Semantics(
      button: true,
      toggled: _on,
      label: widget.label,
      excludeSemantics: true,
      child: InteractiveGlass(
        pressScale: 0.9,
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          setState(() => _on = !_on);
        },
        child: SizedBox.square(
          dimension: KitScene._tile,
          child: Glass(
            shape: const GlassOval(),
            // On, the whole button fills white, like Control Center's; the
            // disc grows out of the centre rather than cutting in.
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedScale(
                  scale: _on ? 1 : 0,
                  duration: duration,
                  curve: _on ? Curves.easeOutBack : Curves.easeIn,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xF2FFFFFF),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: _on ? Tone.ground : Tone.primary),
                  duration: duration,
                  builder: (context, color, _) =>
                      Glyph(widget.icon, size: 26, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlaying extends StatefulWidget {
  const _NowPlaying();

  @override
  State<_NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<_NowPlaying> {
  bool _playing = true;

  @override
  Widget build(BuildContext context) {
    final photo = PlaygroundScope.of(context).photo;
    return InteractiveGlass(
      pressScale: 0.98,
      pressStretch: _tileStretch,
      child: Glass(
        shape: const GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(30)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AnimatedSwitcher(
                  duration: motion(context, const Duration(milliseconds: 400)),
                  child: Image.asset(
                    photo,
                    key: ValueKey(photo),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Refraction',
                style: Font.title.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _Press(
                    label: 'Previous',
                    icon: Glyphs.previous,
                  ),
                  _Press(
                    label: _playing ? 'Pause' : 'Play',
                    icon: _playing ? Glyphs.pause : Glyphs.play,
                    onTap: () => setState(() => _playing = !_playing),
                  ),
                  const _Press(label: 'Next', icon: Glyphs.next),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A painted icon button that squeezes under the finger. No glass of its
/// own: it sits on a tile that already is glass.
class _Press extends StatefulWidget {
  const _Press({required this.label, required this.icon, this.onTap});

  final String label;
  final String icon;
  final VoidCallback? onTap;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _down ? 0.8 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: SizedBox.square(
            dimension: 30,
            child: Center(
              child: AnimatedSwitcher(
                duration: motion(context, const Duration(milliseconds: 200)),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Glyph(
                  widget.icon,
                  key: ValueKey(widget.icon),
                  color: Tone.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled tile with a thin track, dragged anywhere along its width.
class _SliderTile extends StatefulWidget {
  const _SliderTile({
    required this.title,
    required this.low,
    required this.high,
    required this.initial,
  });

  final String title;
  final String low;
  final String high;
  final double initial;

  @override
  State<_SliderTile> createState() => _SliderTileState();
}

class _SliderTileState extends State<_SliderTile> {
  /// Where the track starts and ends inside the tile: past the padding and
  /// the icon at each end.
  static const double _inset = 48;

  late double _value = widget.initial;

  void _set(Offset local, double width) {
    final track = width - _inset * 2;
    setState(() => _value = ((local.dx - _inset) / track).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Semantics(
          slider: true,
          label: widget.title,
          value: '${(_value * 100).round()}%',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => _set(d.localPosition, width),
            onTapDown: (d) => _set(d.localPosition, width),
            child: SizedBox(
              width: width,
              height: 76,
              child: Glass(
                shape: const GlassSuperellipse(
                  radius: BorderRadius.all(Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Font.title.copyWith(fontSize: 15),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Glyph(widget.low, size: 18, color: Tone.primary),
                          const SizedBox(width: 12),
                          Expanded(child: _Track(value: _value)),
                          const SizedBox(width: 12),
                          Glyph(widget.high, size: 20, color: Tone.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0x33FFFFFF)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: const ColoredBox(color: Color(0xFFFFFFFF)),
            ),
          ],
        ),
      ),
    );
  }
}
