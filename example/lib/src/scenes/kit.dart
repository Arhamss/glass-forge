import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/glyphs.dart';
import 'package:glass_forge_example/src/playground.dart';
import 'package:glass_forge_example/src/ui.dart';

/// The same glass as real interface, laid out like Control Center: pill
/// tiles with an icon well, round toggles, a media tile, a switch and two
/// sliders — all of it tuned live by the sheet below.
///
/// The toggles are the package's own [GlassButton]; the switch and the
/// sliders are [GlassSwitch] and [GlassSlider], sitting on tiles that are
/// glass, so they paint rather than stack a second refraction on the first.
/// Eleven glass shapes in all, three past the eight one draw carries.
/// Settled, that is fine: the layer draws shapes that sit apart as separate
/// clusters, and at 12 apart these are. But each row fades in through
/// [Arrive], and a `Glass` under a fully transparent `Opacity` does not
/// paint, so on the first frames it has not been placed yet — every such
/// shape sits at the layer's origin and all eleven read as one cluster,
/// which the layer warns about. So the buttons keep the layer's pass and
/// the modules — media, switch and sliders — take a second one through
/// [_Module]: the same tuned material, two passes of seven and four, and
/// no cluster past eight even before anything has been placed.
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
                  child: _Module(child: _NowPlaying()),
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
            delay: Duration(milliseconds: 90),
            child: Row(
              children: [
                _RoundToggle(icon: Glyphs.torch, label: 'Torch'),
                SizedBox(width: _gap),
                _RoundToggle(icon: Glyphs.timer, label: 'Timer'),
                SizedBox(width: _gap),
                Expanded(child: _Module(child: _SwitchTile())),
              ],
            ),
          ),
          SizedBox(height: _gap),
          Arrive(
            delay: Duration(milliseconds: 120),
            child: _Module(
              child: _SliderTile(
                title: 'Display',
                low: Glyphs.sun,
                high: Glyphs.sunBold,
                initial: 0.55,
              ),
            ),
          ),
          SizedBox(height: _gap),
          Arrive(
            delay: Duration(milliseconds: 180),
            child: _Module(
              child: _SliderTile(
                title: 'Sound',
                low: Glyphs.volumeLow,
                high: Glyphs.volumeHigh,
                initial: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Held by identity: every [_Module] shares this one object, and so one
/// backdrop pass of their own.
const Animation<double> _modulePass = AlwaysStoppedAnimation<double>(1);

/// Puts [child]'s glass in the modules' pass rather than the layer's.
///
/// Passes are keyed by material *and* presence, so a presence that never
/// moves is a second pass wearing the same material — the tuner still
/// reaches it, and the buttons' pass is left with seven shapes.
class _Module extends StatelessWidget {
  const _Module({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPresence(presence: _modulePass, child: child);
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

/// A title over its state, as the pill tiles print it.
class _Caption extends StatelessWidget {
  const _Caption({required this.title, required this.state});

  final String title;
  final String state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Font.title.copyWith(fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        AnimatedSwitcher(
          duration: motion(context, const Duration(milliseconds: 200)),
          child: Text(
            state,
            key: ValueKey(state),
            style: Font.body.copyWith(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A pill tile that toggles: a [GlassButton] in the tile's shape.
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
    // The button's own padding — 10 above and below a 44 pt well — makes
    // the tile's 64.
    return GlassButton(
      toggled: _on,
      shape: _pill,
      pressStretch: _tileStretch,
      semanticLabel: widget.title,
      onPressed: () => setState(() => _on = !_on),
      child: Row(
        children: [
          _Well(icon: widget.icon, on: _on),
          const SizedBox(width: 10),
          Expanded(
            child: ExcludeSemantics(
              child: _Caption(
                title: widget.title,
                state: _on ? widget.on : 'Off',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A round toggle: a [GlassButton] that fills white when on, like Control
/// Center's.
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
    return GlassButton(
      toggled: _on,
      shape: const GlassOval(),
      semanticLabel: widget.label,
      onPressed: () => setState(() => _on = !_on),
      // The button pads its label by 20 across and 10 down; a label of
      // 24 by 44 makes the circle 64. The face overflows that label to
      // fill the whole circle, and the glass clips it round.
      child: SizedBox(
        width: KitScene._tile - 40,
        height: KitScene._tile - 20,
        child: OverflowBox(
          maxWidth: KitScene._tile,
          maxHeight: KitScene._tile,
          child: SizedBox.square(
            dimension: KitScene._tile,
            // The disc grows out of the centre rather than cutting in.
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

/// A pill tile holding a [GlassSwitch]. The tile is glass, so the switch
/// paints its knob rather than refracting on top of it.
class _SwitchTile extends StatefulWidget {
  const _SwitchTile();

  @override
  State<_SwitchTile> createState() => _SwitchTileState();
}

class _SwitchTileState extends State<_SwitchTile> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: KitScene._tile,
      child: Glass(
        shape: _pill,
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 6),
          child: Row(
            children: [
              _Well(icon: Glyphs.battery, on: _on),
              const SizedBox(width: 10),
              Expanded(
                child: ExcludeSemantics(
                  child: _Caption(
                    title: 'Low Power',
                    state: _on ? 'On' : 'Off',
                  ),
                ),
              ),
              GlassSwitch(
                value: _on,
                semanticLabel: 'Low Power Mode',
                onChanged: (on) => setState(() => _on = on),
              ),
            ],
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

/// A titled tile with a [GlassSlider] between two glyphs. The tile is
/// glass, so the slider paints its thumb.
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
  late double _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: Glass(
        shape: const GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Font.title.copyWith(fontSize: 15)),
              const Spacer(),
              Row(
                children: [
                  Glyph(widget.low, size: 18, color: Tone.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassSlider(
                      value: _value,
                      semanticLabel: widget.title,
                      semanticValue: (v) => '${(v * 100).round()}%',
                      onChanged: (v) => setState(() => _value = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Glyph(widget.high, size: 20, color: Tone.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
