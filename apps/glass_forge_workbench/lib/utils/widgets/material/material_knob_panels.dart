import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/material/geometry_group.dart';
import 'package:glass_forge_workbench/utils/widgets/material/light_group.dart';
import 'package:glass_forge_workbench/utils/widgets/material/material_group.dart';
import 'package:glass_forge_workbench/utils/widgets/material/model_group.dart';
import 'package:glass_forge_workbench/utils/widgets/material/optics_group.dart';
import 'package:glass_forge_workbench/utils/widgets/material/tint_group.dart';

/// Every knob a material has, in the groups asked for, each edit handed back
/// as a whole new material.
class MaterialKnobPanels extends StatelessWidget {
  const MaterialKnobPanels({
    required this.material,
    required this.onChanged,
    this.groups = MaterialGroup.values,
    super.key,
  });

  final GlassMaterial material;
  final ValueChanged<GlassMaterial> onChanged;
  final List<MaterialGroup> groups;

  @override
  Widget build(BuildContext context) {
    final m = material;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          if (group != groups.first) const SizedBox(height: AppSpacing.s16),
          switch (group) {
            MaterialGroup.shape => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ModelGroup(
                  profile: m.profile,
                  variant: m.variant,
                  onProfileChanged: (v) => onChanged(m.copyWith(profile: v)),
                  onVariantChanged: (v) => onChanged(m.copyWith(variant: v)),
                ),
                const SizedBox(height: AppSpacing.s16),
                GeometryGroup(
                  showRefractionSpread: m.profile != GlassProfile.dome,
                  thickness: m.thickness,
                  edgeRefraction: m.edgeRefraction,
                  refractionSpread: m.refractionSpread,
                  onThicknessChanged: (v) =>
                      onChanged(m.copyWith(thickness: v)),
                  onEdgeRefractionChanged: (v) =>
                      onChanged(m.copyWith(edgeRefraction: v)),
                  onRefractionSpreadChanged: (v) =>
                      onChanged(m.copyWith(refractionSpread: v)),
                ),
              ],
            ),
            MaterialGroup.optics => OpticsGroup(
              frost: m.frost,
              chromaticAberration: m.chromaticAberration,
              saturation: m.saturation,
              onFrostChanged: (v) => onChanged(m.copyWith(frost: v)),
              onChromaticAberrationChanged: (v) =>
                  onChanged(m.copyWith(chromaticAberration: v)),
              onSaturationChanged: (v) => onChanged(m.copyWith(saturation: v)),
            ),
            MaterialGroup.light => LightGroup(
              highlight: m.highlight,
              contour: m.contour,
              lightDirection: m.lightDirection,
              onHighlightChanged: (v) => onChanged(m.copyWith(highlight: v)),
              onContourChanged: (v) => onChanged(m.copyWith(contour: v)),
              onLightDirectionChanged: (v) =>
                  onChanged(m.copyWith(lightDirection: v)),
            ),
            MaterialGroup.tint => TintGroup(
              tintOpacity: m.tintOpacity,
              tint: m.tint,
              onTintOpacityChanged: (v) =>
                  onChanged(m.copyWith(tintOpacity: v)),
              onTintChanged: (v) => onChanged(m.copyWith(tint: v)),
            ),
          },
        ],
      ],
    );
  }
}
