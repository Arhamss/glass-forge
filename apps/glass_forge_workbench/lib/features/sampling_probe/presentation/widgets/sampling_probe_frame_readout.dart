import 'package:glass_forge_workbench/exports.dart';

/// Shows the rolling average frame time for whichever mode is currently
/// bound, plus the device pixel ratio it was measured at.
///
/// Not a substitute for `glass_forge_benchmark`'s harness — this is a
/// same-device, same-session comparison between the two shaders, useful for
/// telling whether the four-tap reconstruction is affordable at all on the
/// device the probe is running on.
class SamplingProbeFrameReadout extends StatelessWidget {
  /// Creates the readout.
  const SamplingProbeFrameReadout({required this.averageFrameMs, super.key});

  /// Rolling average total frame time, in milliseconds.
  final double averageFrameMs;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final fps = averageFrameMs > 0 ? 1000 / averageFrameMs : 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${averageFrameMs.toStringAsFixed(2)} ms/frame '
            '(~${fps.toStringAsFixed(0)} fps)',
            style: context.p2Medium.copyWith(color: AppColors.textPrimary),
          ),
          Text(
            '${devicePixelRatio.toStringAsFixed(1)}x DPR',
            style: context.p2Medium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
