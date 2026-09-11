import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_tier_extensions.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_value_row.dart';

/// The four signals behind the verdict, each with the ceiling it imposed.
///
/// This is the part no other package can show, so it gets the room: a tier
/// on its own is a number, and "why is this device at reduced?" is the
/// question anyone looking at one actually has.
class TierEvidenceGroup extends StatelessWidget {
  /// Creates the group.
  const TierEvidenceGroup({required this.resolved, super.key});

  /// The engine's verdict, with every input still attached.
  final ResolvedTier resolved;

  String get _capabilityNote {
    final capabilities = resolved.capabilities;
    final geometry = capabilities.complete
        ? (capabilities.acceleratedGeometry
              ? 'Geometry acceleration is available.'
              : 'No geometry acceleration, so the ceiling is balanced.')
        : 'The geometry probe has not finished, so nothing is clamped on '
              'it yet.';
    final filters = capabilities.shaderFilters
        ? 'Shader filters run here.'
        : 'Shader filters throw here, so glass cannot render at all.';
    return '${capabilities.backend.name}. $filters $geometry';
  }

  String get _thermalNote => resolved.thermalIsKnown
      ? 'Reading: ${resolved.thermal!.name}. Fair is common and transient, '
            'so it is deliberately not a downgrade.'
      : 'This platform never answered. Unknown is not the same as cool, so '
            'it imposes no ceiling and is never reported as nominal.';

  String get _frameNote =>
      'Frames are ${resolved.frameHealth.name}. This is the one signal '
      'that steps down relatively instead of naming a floor of its own: it '
      'is a statement about the current workload, not about the device.';

  String get _accessibilityNote {
    final signals = resolved.accessibility;
    final on = <String>[
      if (signals.reduceTransparency) 'Reduce Transparency',
      if (signals.increaseContrast) 'Increase Contrast',
      if (signals.reduceMotion) 'Reduce Motion',
    ];
    final settings = on.isEmpty ? 'Nothing is on.' : '${on.join(', ')} on.';
    final source = signals.reduceTransparencyIsApproximated
        ? ' Reduce Transparency is approximated here rather than read: '
              'this platform did not answer.'
        : ' Read from the platform, not approximated.';
    return '$settings$source A pinned tier does not lift any of this.';
  }

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Why this tier',
      cells: [
        InstrumentValueRow(
          label: 'Capability',
          value: resolved.capabilityCeiling.label.toLowerCase(),
          note: _capabilityNote,
        ),
        InstrumentValueRow(
          label: 'Thermal',
          value: resolved.thermalCeiling.label.toLowerCase(),
          note: _thermalNote,
        ),
        InstrumentValueRow(
          label: 'Frame health',
          value: resolved.frameSteps == 1
              ? '-1 rung'
              : '-${resolved.frameSteps} rungs',
          note: _frameNote,
        ),
        InstrumentValueRow(
          label: 'Accessibility',
          value: resolved.accessibilityCeiling.label.toLowerCase(),
          note: _accessibilityNote,
        ),
      ],
    );
  }
}
