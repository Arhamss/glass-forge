import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/cubit/gallery_cubit.dart';

/// Tells the cubit how tall a surface its half of the stage can draw.
///
/// Without it the size slider ran past what a pane can show, and the
/// readouts beneath described a surface taller than the one on screen.
class StageSizeReporter extends StatelessWidget {
  const StageSizeReporter({required this.child, super.key});

  final Widget child;

  /// Each pane is half the stage; the caption and the backdrop rail take the
  /// rest, and the surface keeps a margin off both.
  static const double _chrome = 72;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight / 2 - _chrome;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.read<GalleryCubit>().setAvailableShortSide(available);
        });
        return child;
      },
    );
  }
}
