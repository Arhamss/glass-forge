import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/stage_caption.dart';

/// States, in pixels and before you look, what the stage should be
/// showing.
///
/// The reason it is phrased as an expectation: a fold that has gone wrong
/// still draws something, and something is easy to accept. A line that
/// says "expect one shape" over two clearly separate circles is not.
class BlendVerdictCaption extends StatelessWidget {
  /// Creates the caption.
  const BlendVerdictCaption({
    required this.edgeGap,
    required this.blend,
    required this.isOverlapping,
    required this.expectsMerge,
    required this.separateNoun,
    super.key,
  });

  /// The distance between the nearest edges, in logical pixels.
  final double edgeGap;

  /// How wide the merge is, in logical pixels.
  final double blend;

  /// Whether the shapes physically intersect.
  final bool isOverlapping;

  /// Whether the fold should bridge the gap.
  final bool expectsMerge;

  /// What to call the shapes when they have not merged.
  final String separateNoun;

  @override
  Widget build(BuildContext context) {
    final gap = isOverlapping
        ? 'overlapping by ${(-edgeGap).toStringAsFixed(0)} px'
        : 'gap ${edgeGap.toStringAsFixed(0)} px';
    final expectation = isOverlapping
        ? 'one shape either way'
        : expectsMerge
        ? 'one shape'
        : separateNoun;
    return StageCaption(
      text: '$gap  ·  blend ${blend.toStringAsFixed(0)} px  →  $expectation',
    );
  }
}
