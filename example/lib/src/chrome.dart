import 'package:flutter/widgets.dart';
import 'package:glass_forge_example/src/theme.dart';

/// A row of choices, painted onto a glass surface.
///
/// Painted, not glass: a glass control drawn on top of a glass bar is the one
/// composition this renderer cannot do — see the note on `Stage` in
/// `main.dart`. Chrome that sits on glass is paint, every time.
///
/// Every colour here comes off the enclosing surface's own label colour. That
/// matters more than it looks: a `GlassSurface.navigationBar` is thin enough
/// to flip its whole scheme against a bright backdrop, and a segmented
/// control that had hard-coded white would then be white on white.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    super.key,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    final index = options.indexOf(selected);
    final count = options.length;
    final duration = sceneDuration(context, const Duration(milliseconds: 240));
    return SizedBox(
      // An explicit height. A `Container` with an alignment inside a bounded
      // slot expands to fill it, which in a bar this size means swallowing
      // the screen.
      height: 40,
      child: Stack(
        children: [
          // The travelling selection, behind the labels so the label a finger
          // is on never flickers under it.
          AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: count == 1
                ? Alignment.center
                : Alignment(-1 + 2 * index / (count - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / count,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.inkFill,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final option in options)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(option),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: duration,
                        style: context.label.copyWith(
                          color: option == selected
                              ? context.ink
                              : context.inkTertiary,
                          fontWeight: option == selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        child: Text(
                          labelOf(option),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A capsule that fills as it is dragged, with its name and value inside it.
///
/// One row instead of the usual label-above-track-below two, because the panel
/// this lives in is competing with the specimen for vertical space and losing
/// is not an option. The knobless fill also keeps the control flat: a round
/// thumb over glass wants a shadow to read, and a shadow on glass is a grey
/// smear.
class ValueSlider extends StatelessWidget {
  const ValueSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.format,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double) format;

  void _setFrom(double dx, double width) {
    final fraction = (dx / width).clamp(0.0, 1.0);
    onChanged(min + (max - min) * fraction);
  }

  @override
  Widget build(BuildContext context) {
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _setFrom(details.localPosition.dx, width),
          onHorizontalDragUpdate: (details) =>
              _setFrom(details.localPosition.dx, width),
          child: SizedBox(
            height: 40,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: context.inkTrack)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction,
                      heightFactor: 1,
                      child: ColoredBox(color: context.inkFill),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(label, style: context.label),
                        const Spacer(),
                        Text(
                          format(value),
                          style: context.mono.copyWith(
                            color: context.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A caption drawn inside a piece of glass.
///
/// Labels belong on the surface they describe rather than floating beside it
/// on the photograph, where they would need a scrim of their own and would
/// clutter the frame with a second kind of chrome.
class GlassCaption extends StatelessWidget {
  const GlassCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, textAlign: TextAlign.center, style: context.mono);
  }
}
