import 'package:flutter/widgets.dart';
import 'package:glass_forge_example/src/theme.dart';

/// A label in a painted pill, which goes somewhere when it is tapped.
///
/// **The catalogue's one tappable-chrome shape, and only that.** A pill
/// promises a destination; anything with nowhere to send the reader is
/// drawn without one. The rule exists because `entry_page.dart`'s see-also
/// row mixes names that open another entry with names the catalogue does
/// not cover, and a row where both look identical promises a tap it cannot
/// honour. `see_also_test.dart` holds the rule: every pill on an entry page
/// has to resolve through `findEntryByApi`.
///
/// Painted, not glass, for the reason every other control in this file is:
/// these sit on a glass bar, and a second piece of glass on top of the
/// first is the one composition this renderer cannot draw.
///
/// The fill is [SurfaceInk.inkFill] over the enclosing surface's own label
/// colour — the step a [SegmentedControl] puts behind its *selected*
/// segment and a [ValueSlider] behind the portion it has filled, not the
/// [SurfaceInk.inkTrack] those two use for the part that is merely
/// available. The reason is the one `inkFill`'s own doc gives: a fill only
/// slightly above the track reads as a smudge rather than as a state, and
/// this is the only control in the app that promises a destination.
///
/// Reading the colour off the surface rather than naming one is what lets a
/// pill invert with a bar that flipped to the light scheme instead of
/// staying white on white.
class PillButton extends StatelessWidget {
  /// Creates a pill reading [label] that calls [onTap].
  const PillButton({required this.label, required this.onTap, super.key});

  /// The text inside the pill.
  final String label;

  /// Where it goes. Non-null by construction: a pill with nothing to do is
  /// the defect this widget exists to make impossible to write.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.inkFill,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: context.label.copyWith(color: context.ink),
          ),
        ),
      ),
    );
  }
}

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
///
/// **Segments are sized from their labels, not cut into equal shares.** Equal
/// shares are the obvious layout and they quietly break the one promise this
/// catalogue makes: that every API name on screen is the real symbol. Five
/// options in a phone-width control give each one about 67 points, and
/// `navigationBar` needs about 84 — and because the labels cannot wrap (a
/// symbol has nowhere to break) the reader sees `navigationBa` fading into
/// nothing. A name shown truncated is worse than no name, because it is one
/// the reader will search for and not find.
///
/// So each segment gets its own label's width first, and whatever is left
/// over is split evenly between them. When the labels are short — which is
/// every other knob in the catalogue — the leftover dominates and the result
/// is the equal-share layout this control has always had, to within a point
/// or two. When one label is long it takes the room it needs from the slack
/// rather than from its neighbours' text.
///
/// Only when the labels do not fit at all does it fall back to splitting the
/// width in proportion to them, so the longest still gets the most room, and
/// [TextOverflow.fade] finally takes over. No knob in this catalogue reaches
/// that case — `segmented_control_test.dart` pumps every one of them at 375
/// and at 320 points and none clips. It is kept for the label nobody has
/// written yet, because a control that overflowed or grew its bar would be
/// a worse answer to one bad label than a faded one is.
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

  /// How wide [text] wants to be, laid out once and thrown away.
  ///
  /// Measured at the *selected* weight for every option, not at each one's
  /// current weight: the labels animate between w500 and w600 as the
  /// selection moves, and widths taken from the live style would make the
  /// segment boundaries breathe on every frame of that animation.
  static double _naturalWidth(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// How the available width is divided between labels of [naturals].
  ///
  /// Natural width plus an equal share of the slack while there is slack;
  /// proportional to natural width once there is not. See the class doc for
  /// why those are the two cases.
  static List<double> _segmentWidths(List<double> naturals, double available) {
    final total = naturals.fold<double>(0, (sum, width) => sum + width);
    if (total <= 0) {
      return <double>[for (final _ in naturals) available / naturals.length];
    }
    final slack = available - total;
    if (slack >= 0) {
      final share = slack / naturals.length;
      return <double>[for (final natural in naturals) natural + share];
    }
    return <double>[
      for (final natural in naturals) available * natural / total,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final index = options.indexOf(selected);
    final duration = sceneDuration(context, const Duration(milliseconds: 240));
    final measuringStyle = context.label.copyWith(
      fontWeight: FontWeight.w600,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    return SizedBox(
      // An explicit height. A `Container` with an alignment inside a bounded
      // slot expands to fill it, which in a bar this size means swallowing
      // the screen.
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widths = _segmentWidths(
            <double>[
              for (final option in options)
                _naturalWidth(
                  labelOf(option),
                  measuringStyle,
                  scaler,
                  direction,
                ),
            ],
            constraints.maxWidth,
          );

          // Integer flexes rather than laid-out pixel widths, so the row can
          // never sum to a hair more than the width it was given and
          // overflow. The pill is positioned from the same integers over the
          // same sum, so it lands exactly on the segment it belongs to.
          final flexes = <int>[
            for (final width in widths)
              (width * 1000).round().clamp(1, 1 << 30),
          ];
          final totalFlex = flexes.fold<int>(0, (sum, flex) => sum + flex);
          final before = flexes
              .take(index < 0 ? 0 : index)
              .fold<int>(
                0,
                (sum, flex) => sum + flex,
              );
          final selectedFlex = index < 0 ? 0 : flexes[index];

          return Stack(
            children: [
              // The travelling selection, behind the labels so the label a
              // finger is on never flickers under it. It resizes as it
              // travels now that the segments are not all one width.
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: constraints.maxWidth * before / totalFlex,
                width: constraints.maxWidth * selectedFlex / totalFlex,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.inkFill,
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < options.length; i++)
                    Expanded(
                      flex: flexes[i],
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(options[i]),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: duration,
                            style: context.label.copyWith(
                              color: options[i] == selected
                                  ? context.ink
                                  : context.inkTertiary,
                              fontWeight: options[i] == selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            child: Text(
                              labelOf(options[i]),
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
          );
        },
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
