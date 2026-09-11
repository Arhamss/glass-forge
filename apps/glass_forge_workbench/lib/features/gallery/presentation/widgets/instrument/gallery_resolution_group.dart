import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_adaptation_extensions.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_surface_role_extensions.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_note.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_value_row.dart';

/// What the selected role actually resolved to, in both apps.
///
/// Every value is read back off the resolved style rather than restated
/// from the spec, so a role whose tint moved to clear its contrast target
/// shows the number it moved to.
class GalleryResolutionGroup extends StatelessWidget {
  /// Creates the group.
  const GalleryResolutionGroup({
    required this.role,
    required this.size,
    required this.adaptation,
    required this.lightStyle,
    required this.darkStyle,
    required this.minimumContrast,
    super.key,
  });

  /// The role being reported on.
  final GlassSurfaceRole role;

  /// The size it resolved at.
  final Size size;

  /// The adaptation the size gate left it with.
  final GlassAdaptation adaptation;

  /// The role resolved in a light app.
  final GlassSurfaceStyle lightStyle;

  /// The role resolved in a dark app.
  final GlassSurfaceStyle darkStyle;

  /// The label contrast this role promises.
  final double minimumContrast;

  String _pair(String light, String dark) => '$light  ·  $dark';

  String _contrast(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}:1';

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Resolved · ${role.label}',
      cells: [
        InstrumentValueRow(
          label: 'Adaptation',
          value: adaptation.verb,
          note: adaptation.consequence,
        ),
        InstrumentValueRow(
          label: 'Scheme',
          value: _pair(lightStyle.brightness.name, darkStyle.brightness.name),
          note: 'In a light app, then a dark one.',
        ),
        InstrumentValueRow(
          label: 'Tint opacity',
          value: _pair(
            '${(lightStyle.material.tintOpacity * 100).toStringAsFixed(0)}%',
            '${(darkStyle.material.tintOpacity * 100).toStringAsFixed(0)}%',
          ),
        ),
        InstrumentValueRow(
          label: 'Frost',
          value: _pair(
            '${lightStyle.material.frost.toStringAsFixed(1)} px',
            '${darkStyle.material.frost.toStringAsFixed(1)} px',
          ),
        ),
        InstrumentValueRow(
          label: 'Corner radius',
          value:
              '${lightStyle.shape.resolveRadius(size).toStringAsFixed(1)}'
              ' px',
        ),
        InstrumentValueRow(
          label: 'Label contrast',
          value: _pair(
            _contrast(lightStyle.labelContrast),
            _contrast(darkStyle.labelContrast),
          ),
          note:
              'Against a target of '
              '${minimumContrast.toStringAsFixed(1)}:1. '
              '${role.blurb}',
        ),
        const InstrumentNote(
          text:
              'All five backdrops here are dark, because the stage is. '
              'So a flipping surface settles on the dark scheme over every '
              'one of them. What you are looking for is that it settles on '
              'the same scheme in both columns, not which scheme it picked.',
        ),
      ],
    );
  }
}
