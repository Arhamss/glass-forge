import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_note.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_value_row.dart';

/// Every axis the effective profile moved, and how far.
///
/// The profile, not the rung's own: an accessibility setting moves axes no
/// performance rung moves, so what is in force can sit off the ladder
/// entirely.
class TierProfileGroup extends StatelessWidget {
  /// Creates the group.
  const TierProfileGroup({required this.profile, super.key});

  /// The effective profile, accessibility overlay included.
  final TierProfile profile;

  String _scale(double value) => '${value.toStringAsFixed(2)}x';

  String _onOff({required bool value}) => value ? 'on' : 'off';

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Effective profile',
      cells: [
        InstrumentValueRow(
          label: 'Geometry producer',
          value: profile.geometry.name,
        ),
        InstrumentValueRow(
          label: 'Refraction',
          value: _scale(profile.refractionScale),
        ),
        InstrumentValueRow(label: 'Blur', value: _scale(profile.blurScale)),
        InstrumentValueRow(
          label: 'Dispersion',
          value: _onOff(value: profile.chromaticAberration),
        ),
        InstrumentValueRow(
          label: 'Specular',
          value: _scale(profile.specularScale),
        ),
        InstrumentValueRow(
          label: 'Tint floor',
          value: '${(profile.minimumTintOpacity * 100).toStringAsFixed(0)}%',
        ),
        InstrumentValueRow(
          label: 'Contour floor',
          value: profile.minimumContour.toStringAsFixed(2),
        ),
        InstrumentValueRow(
          label: 'Elastic motion',
          value: _onOff(value: profile.elasticMotion),
          note: 'Read by the motion layer, not the renderer. Reduce Motion '
              'is a statement about springs, not about pixels.',
        ),
        const InstrumentNote(
          text: 'Scales run before floors, so a floor always wins. A '
              'performance rung must not be able to undo something a user '
              'asked for.',
        ),
      ],
    );
  }
}
