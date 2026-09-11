import 'package:glass_forge_workbench/exports.dart';

/// A compact circular control for `GlassMaterial.lightDirection`.
///
/// Apple feeds this from the accelerometer on phones; the workbench has no
/// tilt signal to drive it from, so dragging around the dial stands in for
/// it directly — one control instead of the two raw sliders an x/y pair
/// would otherwise need.
class LightDirectionDial extends StatelessWidget {
  /// Creates the dial.
  const LightDirectionDial({
    required this.direction,
    required this.onChanged,
    super.key,
  });

  /// The light's current direction.
  final Offset direction;

  /// Called with the newly picked, unit-length direction.
  final ValueChanged<Offset> onChanged;

  static const double _diameter = 44;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => _emitFromLocal(details.localPosition),
      onTapDown: (details) => _emitFromLocal(details.localPosition),
      child: Container(
        width: _diameter,
        height: _diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.stageGround,
          border: Border.all(color: AppColors.stageBorder),
        ),
        child: CustomPaint(
          painter: LightDirectionDialPainter(direction: direction),
        ),
      ),
    );
  }

  void _emitFromLocal(Offset local) {
    const center = Offset(_diameter / 2, _diameter / 2);
    final delta = local - center;
    if (delta.distance < 1) {
      return;
    }
    onChanged(delta / delta.distance);
  }
}

/// Paints [LightDirectionDial]'s direction indicator.
class LightDirectionDialPainter extends CustomPainter {
  /// Creates the painter.
  const LightDirectionDialPainter({required this.direction});

  /// The direction the indicator points toward.
  final Offset direction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    final normalized = direction.distance == 0
        ? const Offset(0, 1)
        : direction / direction.distance;
    final tip = center + normalized * radius;

    final linePaint = Paint()
      ..color = AppColors.stageForegroundMuted
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(center, tip, linePaint)
      ..drawCircle(tip, 3.5, Paint()..color = AppColors.stageForeground);
  }

  @override
  bool shouldRepaint(covariant LightDirectionDialPainter oldDelegate) =>
      oldDelegate.direction != direction;
}
