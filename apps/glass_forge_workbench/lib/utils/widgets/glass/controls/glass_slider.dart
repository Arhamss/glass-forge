import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/reduce_motion.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

/// A painted track with a glass lens for a thumb. Drag anywhere on it; the
/// lens swells while held and magnifies the fill edge it sits on.
class GlassSlider extends StatefulWidget {
  const GlassSlider({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.min = 0,
    this.max = 1,
    this.formatValue,
    this.material,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final String semanticLabel;

  /// How a screen reader says a value, with its unit. Defaults to a
  /// percentage of the range. Used for the value and for what one step up or
  /// down would make it.
  final String Function(double value)? formatValue;

  /// Null uses the house material.
  final GlassMaterial? material;

  @override
  State<GlassSlider> createState() => _GlassSliderState();
}

class _GlassSliderState extends State<GlassSlider> {
  static const double _height = 44;
  static const double _track = 6;
  static const Size _thumb = Size(38, 26);

  final ValueNotifier<bool> _held = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _held.dispose();
    super.dispose();
  }

  double get _fraction => widget.max == widget.min
      ? 0
      : ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0, 1);

  void _seek(double localX, double width) {
    final travel = width - _thumb.width;
    var fraction = ((localX - _thumb.width / 2) / travel).clamp(0.0, 1.0);
    if (Directionality.of(context) == TextDirection.rtl) {
      fraction = 1 - fraction;
    }
    widget.onChanged(widget.min + fraction * (widget.max - widget.min));
  }

  double get _step => (widget.max - widget.min) / 20;

  double _stepped(double direction) =>
      (widget.value + _step * direction).clamp(widget.min, widget.max);

  void _nudge(double direction) => widget.onChanged(_stepped(direction));

  String _format(double value) {
    final format = widget.formatValue;
    if (format != null) return format(value);
    final range = widget.max - widget.min;
    final fraction = range == 0 ? 0 : (value - widget.min) / range;
    return '${(fraction * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _fraction;
    final reduceMotion = context.reduceMotion;
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: _format(widget.value),
      increasedValue: _format(_stepped(1)),
      decreasedValue: _format(_stepped(-1)),
      onIncrease: () => _nudge(1),
      onDecrease: () => _nudge(-1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final travel = width - _thumb.width;
          return GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _seek(d.localPosition.dx, width),
            onHorizontalDragStart: (d) {
              _held.value = true;
              _seek(d.localPosition.dx, width);
            },
            onHorizontalDragUpdate: (d) => _seek(d.localPosition.dx, width),
            onHorizontalDragEnd: (_) => _held.value = false,
            onHorizontalDragCancel: () => _held.value = false,
            child: SizedBox(
              height: _height,
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  PositionedDirectional(
                    start: _thumb.width / 2,
                    end: _thumb.width / 2,
                    child: Container(
                      height: _track,
                      decoration: BoxDecoration(
                        color: AppColors.hairlineStrong,
                        borderRadius: BorderRadius.circular(_track / 2),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: _thumb.width / 2,
                    width: travel * fraction,
                    child: Container(
                      height: _track,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(_track / 2),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: travel * fraction,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _held,
                      builder: (context, held, child) => AnimatedScale(
                        scale: held && !reduceMotion ? 1.18 : 1,
                        duration: AppMotion.press,
                        child: child,
                      ),
                      child: SizedBox.fromSize(
                        size: _thumb,
                        child: KitGlassLayer(
                          priority: GlassPriority.content,
                          material: widget.material,
                          insetTint: AppColors.white,
                          shape: GlassSuperellipse(
                            radius: BorderRadius.all(
                              Radius.circular(_thumb.height / 2),
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
