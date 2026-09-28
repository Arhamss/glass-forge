import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/controls.dart';
import 'package:glass_forge_example/src/glyphs.dart';
import 'package:glass_forge_example/src/playground.dart';
import 'package:glass_forge_example/src/presets.dart';
import 'package:glass_forge_example/src/ui.dart';

/// Everything that goes into a `GlassMaterial`, one control per field.
///
/// The header and the preset chips are what shows while the sheet is
/// lowered; the rest scrolls into view as it rises.
class Tuner extends StatelessWidget {
  const Tuner({required this.onCopied, super.key});

  /// Called after the material's Dart has been put on the clipboard.
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 40),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _inset),
          child: _Header(onCopied: onCopied),
        ),
        const SizedBox(height: 14),
        const _PresetStrip(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _controls(context),
          ),
        ),
      ],
    );
  }

  /// How far the content sits in from the sheet's sides — enough to clear
  /// the curve of its floating corners.
  static const double _inset = 20;

  List<Widget> _controls(BuildContext context) {
    final playground = PlaygroundScope.of(context);
    final m = playground.material;
    void tweak(GlassMaterial next) => playground.tweak(next);

    final angle = math.atan2(m.lightDirection.dy, m.lightDirection.dx);
    final degrees = (angle * 180 / math.pi + 360) % 360;

    return [
      const SectionLabel('Shape of the lens'),
      _Choice<GlassProfile>(
        options: GlassProfile.values,
        selected: m.profile,
        labelOf: (p) => p == GlassProfile.edgeBand ? 'Edge band' : 'Dome',
        onChanged: (p) => tweak(m.copyWith(profile: p)),
      ),
      const SizedBox(height: 8),
      _Choice<GlassVariant>(
        options: GlassVariant.values,
        selected: m.variant,
        labelOf: (v) => v == GlassVariant.regular ? 'Regular' : 'Clear',
        onChanged: (v) => tweak(m.copyWith(variant: v)),
      ),
      const SectionLabel('Refraction'),
      ..._spaced([
        _Knob(
          label: 'Bend',
          value: m.edgeRefraction,
          min: 0,
          max: 80,
          format: (v) => '${v.round()} px',
          onChanged: (v) => tweak(m.copyWith(edgeRefraction: v)),
        ),
        _Knob(
          label: 'Thickness',
          value: m.thickness,
          min: 1,
          max: 40,
          format: (v) => '${v.round()} px',
          onChanged: (v) => tweak(m.copyWith(thickness: v)),
        ),
        _Knob(
          label: 'Spread',
          value: m.refractionSpread,
          min: 0,
          max: 0.2,
          format: (v) => v.toStringAsFixed(2),
          onChanged: (v) => tweak(m.copyWith(refractionSpread: v)),
        ),
        _Knob(
          label: 'Dispersion',
          value: m.chromaticAberration,
          min: 0,
          max: 0.6,
          format: (v) => v.toStringAsFixed(2),
          onChanged: (v) => tweak(m.copyWith(chromaticAberration: v)),
        ),
      ]),
      const SectionLabel('Surface'),
      ..._spaced([
        _Knob(
          label: 'Frost',
          value: m.frost,
          min: 0,
          max: 12,
          format: (v) => v.toStringAsFixed(1),
          onChanged: (v) => tweak(m.copyWith(frost: v)),
        ),
        _Knob(
          label: 'Saturation',
          value: m.saturation,
          min: 0,
          max: 3,
          format: (v) => '${v.toStringAsFixed(2)}×',
          onChanged: (v) => tweak(m.copyWith(saturation: v)),
        ),
        _Knob(
          label: 'Tint',
          value: m.tintOpacity,
          min: 0,
          max: 1,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => tweak(m.copyWith(tintOpacity: v)),
        ),
        _Swatches(
          selected: m.tint,
          onChanged: (c) => tweak(
            m.copyWith(
              tint: c,
              tintOpacity: m.tintOpacity < 0.05 ? 0.25 : m.tintOpacity,
            ),
          ),
        ),
      ]),
      const SectionLabel('Light'),
      ..._spaced([
        _Knob(
          label: 'Highlight',
          value: m.highlight,
          min: 0,
          max: 2,
          format: (v) => v.toStringAsFixed(2),
          onChanged: (v) => tweak(m.copyWith(highlight: v)),
        ),
        _Knob(
          label: 'Light angle',
          value: degrees,
          min: 0,
          max: 359,
          format: (v) => '${v.round()}°',
          onChanged: (v) {
            final r = v * math.pi / 180;
            tweak(
              m.copyWith(lightDirection: Offset(math.cos(r), math.sin(r))),
            );
          },
        ),
        _Knob(
          label: 'Contour',
          value: m.contour,
          min: 0,
          max: 0.6,
          format: (v) => v.toStringAsFixed(2),
          onChanged: (v) => tweak(m.copyWith(contour: v)),
        ),
      ]),
      const SectionLabel('Liquid'),
      _Knob(
        label: 'Blend',
        value: playground.blend,
        min: 0,
        max: 60,
        format: (v) => '${v.round()} px',
        onChanged: (v) => playground.blend = v,
      ),
      const SectionLabel('Quality tier'),
      _Choice<GlassTier?>(
        options: const [
          null,
          GlassTier.full,
          GlassTier.balanced,
          GlassTier.reduced,
          GlassTier.flat,
        ],
        selected: playground.tier,
        labelOf: (t) => switch (t) {
          null => 'Auto',
          GlassTier.full => 'Full',
          GlassTier.balanced => 'Bal.',
          GlassTier.reduced => 'Less',
          GlassTier.flat => 'Flat',
          GlassTier.off => 'Off',
        },
        onChanged: (t) => playground.tier = t,
      ),
      const _TierReport(),
    ];
  }

  static List<Widget> _spaced(List<Widget> children) => [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) const SizedBox(height: 8),
      children[i],
    ],
  ];
}

/// A labelled [GlassSlider]: the name and the value printed above the
/// track. The tuner sits on the sheet's glass, so the slider paints.
class _Knob extends StatelessWidget {
  const _Knob({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double value) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    // A preset may sit past a slider's range; the slider shows it pinned
    // at the end rather than refusing it.
    final shown = value.clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(label, style: Font.body.copyWith(color: Tone.primary)),
              const Spacer(),
              Text(
                format(value),
                style: Font.mono.copyWith(color: Tone.secondary),
              ),
            ],
          ),
        ),
        GlassSlider(
          value: shown,
          min: min,
          max: max,
          semanticLabel: label,
          semanticValue: format,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// A [GlassSegmentedControl] over [options], each named by [labelOf].
///
/// The type is set here and the colour left to the control, which draws
/// the chosen label dark on the white pill it paints on the sheet's glass.
/// The others are dimmed to the tuner's secondary tone.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    super.key,
  });

  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onChanged;

  /// [Font.body] at 13, with no colour of its own to override the
  /// control's.
  static const TextStyle _type = TextStyle(
    fontFamily: 'Geist',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
  );

  static const TextStyle _dimmed = TextStyle(color: Tone.secondary);

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: _type,
      child: GlassSegmentedControl<T>(
        selected: selected,
        onChanged: (option) {
          unawaited(HapticFeedback.selectionClick());
          onChanged(option);
        },
        segments: [
          for (final option in options)
            GlassSegment<T>(
              value: option,
              label: Text(
                labelOf(option),
                style: option == selected ? null : _dimmed,
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCopied});

  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final playground = PlaygroundScope.of(context);
    final duration = motion(context, const Duration(milliseconds: 220));
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const Text('Material', style: Font.title),
          const SizedBox(width: 10),
          // The selected chip already names the preset; this only speaks up
          // once a slider has moved the material off every preset.
          AnimatedSwitcher(
            duration: duration,
            switchInCurve: settle,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: playground.preset == null
                ? const _Tag('Edited')
                : const SizedBox.shrink(),
          ),
          const Spacer(),
          _RoundAction(
            icon: Glyphs.reset,
            label: 'Reset',
            onTap: playground.reset,
          ),
          const SizedBox(width: 2),
          _RoundAction(
            icon: Glyphs.code,
            label: 'Copy as Dart',
            onTap: () async {
              await Clipboard.setData(
                ClipboardData(text: dartFor(playground.material)),
              );
              onCopied();
            },
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Tone.hairline),
      ),
      child: Text(
        text.toUpperCase(),
        style: Font.mono.copyWith(
          fontSize: 10,
          letterSpacing: 1,
          color: Tone.secondary,
        ),
      ),
    );
  }
}

/// A 36pt circular icon button: secondary to the presets, not competing
/// with them.
class _RoundAction extends StatefulWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_RoundAction> createState() => _RoundActionState();
}

class _RoundActionState extends State<_RoundAction> {
  bool _down = false;

  void _press(bool down) {
    if (_down != down) {
      setState(() => _down = down);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, const Duration(milliseconds: 140));
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          widget.onTap();
        },
        // 44pt of target around a 36pt disc.
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedScale(
            scale: _down ? 0.9 : 1,
            duration: duration,
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: duration,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _down ? Tone.hairline : Tone.wash,
                border: Border.all(color: Tone.hairline, width: 0.5),
              ),
              child: Glyph(widget.icon, size: 18, color: Tone.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// The presets, edge to edge across the sheet.
///
/// The strip runs under the sheet's rounded sides rather than stopping at
/// the content inset, and fades out at both ends, so a chip scrolling off
/// dissolves instead of being sliced by a hard edge.
class _PresetStrip extends StatelessWidget {
  const _PresetStrip();

  static const double _fade = 28;

  @override
  Widget build(BuildContext context) {
    final playground = PlaygroundScope.of(context);
    return SizedBox(
      height: 38,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          final edge = (_fade / bounds.width).clamp(0.0, 0.5);
          return LinearGradient(
            colors: const [
              Color(0x00FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0, edge, 1 - edge, 1],
          ).createShader(bounds);
        },
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Tuner._inset),
          itemCount: presets.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) => PresetChip(
            label: presets[i].name,
            selected: playground.preset == presets[i].name,
            onTap: () => playground.applyPreset(presets[i]),
          ),
        ),
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.selected, required this.onChanged});

  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final color in tints)
          Semantics(
            button: true,
            selected: color == selected,
            label: 'Tint colour',
            child: GestureDetector(
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                onChanged(color);
              },
              child: AnimatedContainer(
                duration: motion(context, const Duration(milliseconds: 240)),
                curve: Curves.easeOutBack,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color == selected ? Tone.primary : Tone.hairline,
                    width: color == selected ? 3 : 1,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The engine's own account of why it picked the tier it did.
class _TierReport extends StatelessWidget {
  const _TierReport();

  @override
  Widget build(BuildContext context) {
    final resolved = GlassTierScope.maybeOf(context);
    if (resolved == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rendering at ${resolved.tier.name}',
            style: Font.body.copyWith(color: Tone.primary),
          ),
          const SizedBox(height: 6),
          Text(resolved.describe(), style: Font.mono.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
