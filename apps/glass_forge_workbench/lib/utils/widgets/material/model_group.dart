import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_profile_extensions.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_variant_extensions.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_segmented_control.dart';

/// The two choices that change which optical model a material is, rather
/// than how strongly it applies: the edge band or the dome, regular or clear.
class ModelGroup extends StatelessWidget {
  const ModelGroup({
    required this.profile,
    required this.variant,
    required this.onProfileChanged,
    required this.onVariantChanged,
    super.key,
  });

  final GlassProfile profile;
  final GlassVariant variant;
  final ValueChanged<GlassProfile> onProfileChanged;
  final ValueChanged<GlassVariant> onVariantChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InstrumentPanel(
      title: l10n.groupModel,
      cells: [
        InstrumentSegmentedControl<GlassProfile>(
          values: GlassProfile.values,
          labels: [for (final value in GlassProfile.values) value.label],
          selected: profile,
          onChanged: onProfileChanged,
        ),
        InstrumentSegmentedControl<GlassVariant>(
          values: GlassVariant.values,
          labels: [for (final value in GlassVariant.values) value.label],
          selected: variant,
          onChanged: onVariantChanged,
        ),
      ],
    );
  }
}
