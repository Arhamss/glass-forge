import 'dart:math' as math;

import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/helpers/demonstration_glass_material.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrop_rail.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/glass_backdrop_surface.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/stage_caption.dart';

/// One specimen, rendered at whatever tier the engine settled on.
///
/// The layer is given the material a developer would write. What lands on
/// screen is that material after the resolved tier has taken things away
/// from it, which is the whole claim this screen is here to make
/// checkable.
class TierStage extends StatelessWidget {
  /// Creates the stage.
  const TierStage({
    required this.backdrop,
    required this.tierName,
    required this.isForced,
    required this.onBackdropChanged,
    super.key,
  });

  /// The backdrop behind the specimen.
  final GlassBackdrop backdrop;

  /// The tier currently in force.
  final String tierName;

  /// Whether that tier was pinned rather than resolved.
  final bool isForced;

  /// Called when a different backdrop is picked from the rail.
  final ValueChanged<GlassBackdrop> onBackdropChanged;

  /// Fraction of the stage's shorter dimension the specimen occupies.
  static const _specimenSizeFraction = 0.52;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GlassBackdropSurface(backdrop: backdrop),
        LayoutBuilder(
          builder: (context, constraints) {
            final size =
                math.min(constraints.maxWidth, constraints.maxHeight) *
                _specimenSizeFraction;
            return Center(
              child: GlassLayer(
                material: demonstrationGlassMaterial(),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: const Glass(
                    shape: GlassSuperellipse(
                      radius: BorderRadius.all(Radius.circular(28)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StageCaption(
                text: isForced
                    ? 'tier $tierName  ·  pinned'
                    : 'tier $tierName  ·  resolved',
                isLive: isForced,
              ),
              const SizedBox(height: 12),
              BackdropRail(
                selected: backdrop,
                onChanged: onBackdropChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
