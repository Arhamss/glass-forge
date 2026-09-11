import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/widgets/gallery_surface_specimen.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/glass_backdrop_surface.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/stage_caption.dart';

/// Half the gallery stage: the selected role over the backdrop, in an app
/// pinned to one brightness.
///
/// Two of these, one light and one dark, are what make adaptation legible.
/// A surface that flips reads the same in both; a surface that adapts does
/// not.
class GallerySchemePane extends StatelessWidget {
  /// Creates the pane.
  const GallerySchemePane({
    required this.ambient,
    required this.role,
    required this.size,
    required this.style,
    required this.backdrop,
    super.key,
  });

  /// The brightness the app is running in this pane.
  final Brightness ambient;

  /// The role on show.
  final GlassSurfaceRole role;

  /// The size the role is drawn at.
  final Size size;

  /// The role resolved against [size], [backdrop] and [ambient].
  final GlassSurfaceStyle style;

  /// The backdrop painted behind the surface.
  final GlassBackdrop backdrop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GlassBackdropSurface(backdrop: backdrop),
        Center(
          child: GlassTheme(
            data: ambient == Brightness.light
                ? GlassThemeData.light
                : GlassThemeData.dark,
            child: GallerySurfaceSpecimen(
              role: role,
              size: size,
              style: style,
              backdropColor: backdrop.meanColor,
            ),
          ),
        ),
        PositionedDirectional(
          top: 12,
          start: 16,
          end: 16,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StageCaption(
              text: '${ambient.name} app  →  ${style.brightness.name} glass',
            ),
          ),
        ),
      ],
    );
  }
}
