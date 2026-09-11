import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/demonstration_glass_material.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_value_row.dart';

/// The specimen's material as written, and as it survives the tier.
///
/// The last step of the argument: a rung is a set of multipliers until you
/// see what it did to the numbers being rendered above. The scheme is read
/// the same way `GlassLayer` reads it, so these are the values the stage
/// really got and not a second guess at them.
class TierMaterialGroup extends StatelessWidget {
  /// Creates the group.
  const TierMaterialGroup({required this.resolved, super.key});

  /// The engine's verdict, which does the degrading.
  final ResolvedTier resolved;

  String _pixels(double asked, double got) =>
      '${got.toStringAsFixed(1)} px  ·  was ${asked.toStringAsFixed(1)}';

  @override
  Widget build(BuildContext context) {
    final written = demonstrationGlassMaterial();
    final effective = resolved.materialFor(
      written,
      brightness: MediaQuery.platformBrightnessOf(context),
    );
    return InstrumentPanel(
      title: 'Material on the stage',
      cells: [
        InstrumentValueRow(
          label: 'Edge refraction',
          value: _pixels(written.edgeRefraction, effective.edgeRefraction),
        ),
        InstrumentValueRow(
          label: 'Frost',
          value: _pixels(written.frost, effective.frost),
        ),
        InstrumentValueRow(
          label: 'Dispersion',
          value: _pixels(
            written.chromaticAberration,
            effective.chromaticAberration,
          ),
        ),
        InstrumentValueRow(
          label: 'Tint opacity',
          value:
              '${(effective.tintOpacity * 100).toStringAsFixed(0)}%  ·  was '
              '${(written.tintOpacity * 100).toStringAsFixed(0)}%',
        ),
        InstrumentValueRow(
          label: 'Renders anything',
          value: effective.rendersAnything ? 'yes' : 'no',
          note: 'When this reads no, the layer pushes no backdrop pass at '
              'all, so the surface costs nothing instead of paying for a '
              'filter that draws nothing.',
        ),
      ],
    );
  }
}
