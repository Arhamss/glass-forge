import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge_example/src/ui.dart';

/// A pill you drag along, with its label and value printed inside it.
///
/// Painted rather than a Material `Slider`: a thumb and a track read as a
/// form, and this is closer to Control Center — the whole row is the handle.
class TuneSlider extends StatelessWidget {
  const TuneSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.format,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double value)? format;

  @override
  Widget build(BuildContext context) {
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final text = format?.call(value) ?? value.toStringAsFixed(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void set(Offset local) {
          final next = min + (local.dx / width).clamp(0.0, 1.0) * (max - min);
          if ((next == min || next == max) && next != value) {
            unawaited(HapticFeedback.selectionClick());
          }
          onChanged(next);
        }

        return Semantics(
          slider: true,
          label: label,
          value: text,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) => set(d.localPosition),
            onHorizontalDragUpdate: (d) => set(d.localPosition),
            onTapDown: (d) => set(d.localPosition),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 44,
                child: Stack(
                  children: [
                    const ColoredBox(
                      color: Tone.wash,
                      child: SizedBox.expand(),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      heightFactor: 1,
                      child: const ColoredBox(color: Color(0x30FFFFFF)),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Text(
                              label,
                              style: Font.body.copyWith(color: Tone.primary),
                            ),
                            const Spacer(),
                            Text(
                              text,
                              style: Font.mono.copyWith(color: Tone.secondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A segmented control whose thumb slides between options.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    super.key,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T option) labelOf;

  @override
  Widget build(BuildContext context) {
    final index = options.indexOf(selected);
    final x = options.length == 1 ? 0.0 : -1 + 2 * index / (options.length - 1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: Tone.wash,
        child: SizedBox(
          height: 40,
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: Alignment(x, 0),
                duration: motion(context, const Duration(milliseconds: 420)),
                curve: settle,
                child: FractionallySizedBox(
                  widthFactor: 1 / options.length,
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xF2FFFFFF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: option == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            onChanged(option);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: motion(
                                context,
                                const Duration(milliseconds: 220),
                              ),
                              style: Font.body.copyWith(
                                fontSize: 13,
                                color: option == selected
                                    ? Tone.ground
                                    : Tone.secondary,
                              ),
                              child: Text(labelOf(option)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A preset chip: white when chosen, a faint wash otherwise.
class PresetChip extends StatelessWidget {
  const PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, const Duration(milliseconds: 260));
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xF2FFFFFF) : Tone.wash,
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            style: Font.body.copyWith(
              color: selected ? Tone.ground : Tone.primary,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// A small caps heading for a group of controls.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: Font.mono.copyWith(letterSpacing: 1.2),
      ),
    );
  }
}
