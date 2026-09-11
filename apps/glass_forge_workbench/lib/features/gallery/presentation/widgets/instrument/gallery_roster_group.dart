import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/cubit/gallery_state.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/widgets/instrument/gallery_roster_row.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_note.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';

/// All five roles at once, each with the verdict the current size earns
/// it. Tapping one puts it on the stage.
class GalleryRosterGroup extends StatelessWidget {
  /// Creates the group.
  const GalleryRosterGroup({
    required this.state,
    required this.onRoleChanged,
    super.key,
  });

  /// The gallery's current state, which every row is derived from.
  final GalleryState state;

  /// Called with the newly picked role.
  final ValueChanged<GlassSurfaceRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Surfaces',
      cells: [
        for (final role in GlassSurfaceRole.values)
          GalleryRosterRow(
            role: role,
            adaptation: state.adaptationOf(role),
            lightScheme: state.styleOf(role, Brightness.light).brightness,
            darkScheme: state.styleOf(role, Brightness.dark).brightness,
            isSelected: role == state.role,
            onTap: () => onRoleChanged(role),
          ),
        const InstrumentNote(
          text:
              'Two schemes that match mean the surface stopped listening '
              'to the app and started listening to its backdrop. Two that '
              'differ mean it kept the app scheme and paid for legibility '
              'in tint instead.',
        ),
      ],
    );
  }
}
