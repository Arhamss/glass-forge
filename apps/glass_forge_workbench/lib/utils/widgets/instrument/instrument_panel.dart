import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_grid_texture.dart';

/// The solid, never-glass control sheet beneath every stage.
///
/// Apple's own glass guidance is "never glass on glass," and practically: a
/// glass instrument panel re-tints every time the specimen above it
/// changes, which makes the control you're dragging unreadable while you
/// drag it. This sheet stays solid so the numbers stay legible no matter
/// what the stage is doing.
class InstrumentPanel extends StatelessWidget {
  /// Creates the panel.
  const InstrumentPanel({required this.title, required this.cells, super.key});

  /// The group heading shown above [cells], e.g. `'Material'`.
  final String title;

  /// The rows in this group, separated by hairline dividers.
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.stageRaised),
      child: Stack(
        children: [
          const Positioned.fill(child: InstrumentGridTexture()),
          Padding(
            padding: const EdgeInsetsDirectional.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: context.overline.copyWith(
                    color: AppColors.stageForegroundSubtle,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < cells.length; i++) ...[
                  cells[i],
                  if (i != cells.length - 1) ...[
                    const SizedBox(height: 16),
                    const Divider(
                      color: AppColors.stageDivider,
                      height: 1,
                      thickness: 1,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
