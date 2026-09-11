import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/widgets/gallery_scheme_pane.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrop_rail.dart';

/// The gallery stage: the same role twice, once in a light app and once in
/// a dark one, over one shared backdrop.
class GalleryStage extends StatelessWidget {
  /// Creates the stage.
  const GalleryStage({
    required this.role,
    required this.size,
    required this.lightStyle,
    required this.darkStyle,
    required this.backdrop,
    required this.onBackdropChanged,
    super.key,
  });

  /// The role on show in both panes.
  final GlassSurfaceRole role;

  /// The size it is drawn at.
  final Size size;

  /// The role resolved in a light app.
  final GlassSurfaceStyle lightStyle;

  /// The role resolved in a dark app.
  final GlassSurfaceStyle darkStyle;

  /// The backdrop behind both panes.
  final GlassBackdrop backdrop;

  /// Called when a different backdrop is picked from the rail.
  final ValueChanged<GlassBackdrop> onBackdropChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(
              child: GallerySchemePane(
                ambient: Brightness.light,
                role: role,
                size: size,
                style: lightStyle,
                backdrop: backdrop,
              ),
            ),
            const Divider(
              color: AppColors.stageBorder,
              height: 1,
              thickness: 1,
            ),
            Expanded(
              child: GallerySchemePane(
                ambient: Brightness.dark,
                role: role,
                size: size,
                style: darkStyle,
                backdrop: backdrop,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: BackdropRail(selected: backdrop, onChanged: onBackdropChanged),
        ),
      ],
    );
  }
}
