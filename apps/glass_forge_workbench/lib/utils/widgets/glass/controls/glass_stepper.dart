import 'dart:async';

import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/haptic_helper.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/controls/glass_stepper_side.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

/// Minus, a value, plus, on one glass capsule. Hold a side to keep stepping.
class GlassStepper extends StatefulWidget {
  const GlassStepper({
    required this.value,
    required this.onChanged,
    required this.decrementLabel,
    required this.incrementLabel,
    this.min = 0,
    this.max = 99,
    this.material,
    super.key,
  });

  static const double height = 44;

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String decrementLabel;
  final String incrementLabel;

  /// Null uses the house material.
  final GlassMaterial? material;

  @override
  State<GlassStepper> createState() => _GlassStepperState();
}

class _GlassStepperState extends State<GlassStepper> {
  static const _repeatDelay = Duration(milliseconds: 380);
  static const _repeatEvery = Duration(milliseconds: 90);

  Timer? _repeat;

  // The latest value, for repeats that fire between rebuilds.
  late int _value = widget.value;

  @override
  void didUpdateWidget(GlassStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _value = widget.value;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  bool _canStep(int delta) {
    final next = _value + delta;
    return next >= widget.min && next <= widget.max;
  }

  void _step(int delta) {
    if (!_canStep(delta)) {
      _stopRepeat();
      return;
    }
    AppHaptics.toggle();
    _value += delta;
    widget.onChanged(_value);
  }

  void _startRepeat(int delta) {
    _repeat?.cancel();
    _repeat = Timer(_repeatDelay, () {
      _repeat = Timer.periodic(_repeatEvery, (_) => _step(delta));
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: GlassStepper.height,
      child: KitGlassLayer(
        priority: GlassPriority.content,
        material: widget.material,
        shape: const GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(GlassStepper.height / 2)),
        ),
        child: ColoredBox(
          color: AppColors.glassChromeScrim,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassStepperSide(
                icon: AssetPaths.minus,
                label: widget.decrementLabel,
                enabled: _canStep(-1),
                onStep: () => _step(-1),
                onHoldStart: () => _startRepeat(-1),
                onHoldEnd: _stopRepeat,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 32),
                child: Text(
                  '${widget.value}',
                  textAlign: TextAlign.center,
                  style: context.mono,
                ),
              ),
              GlassStepperSide(
                icon: AssetPaths.plus,
                label: widget.incrementLabel,
                enabled: _canStep(1),
                onStep: () => _step(1),
                onHoldStart: () => _startRepeat(1),
                onHoldEnd: _stopRepeat,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
