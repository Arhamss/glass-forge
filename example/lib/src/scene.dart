import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/theme.dart';

/// Everything the stage needs to know about a scene before building it.
///
/// The photograph, the material the layer captures with, and the colour that
/// is actually behind the chrome at the bottom of the frame. That last one is
/// what turns adaptation on: `GlassSurface` will flip or thicken a surface to
/// keep its labels readable, but nothing in the package samples the backdrop
/// for you, so a scene that knows what it put there says so.
@immutable
class SceneInfo {
  const SceneInfo({
    required this.name,
    required this.blurb,
    required this.photo,
    required this.panelBackdrop,
    required this.barBackdrop,
    required this.material,
  });

  /// One word. It is the scene's title and its tab, and they must agree.
  final String name;

  /// One sentence, under the title. Two lines at most on a phone.
  final String blurb;

  /// The full-bleed photograph, painted behind the glass layer.
  final String photo;

  /// The mean colour under the control panel, measured off [photo].
  final Color panelBackdrop;

  /// The mean colour under the tab bar, measured off [photo].
  ///
  /// A second sample rather than one for the whole bottom of the frame: the
  /// two bars sit over different bands of the picture, and on the dunes those
  /// bands are a shadowed trough and a sunlit crest. Averaging them together
  /// under-tints whichever surface is over the brighter one, which is exactly
  /// the surface that needed the tint.
  ///
  /// Both were measured over the strip each bar actually covers *after*
  /// `BoxFit.cover` has cropped the photograph — on a phone that keeps the
  /// middle 61% of these files' width — because the promise the tint ladder
  /// makes is a contrast number, and a number measured against pixels that
  /// are off-screen is fiction.
  final Color barBackdrop;

  /// What the layer captures with, and what every `Glass` under it inherits.
  final GlassMaterial material;
}

/// The five scenes, in the order the tab bar shows them.
///
/// Photographs were generated for this project, so they ship with the
/// example rather than being fetched at run time. Each one was picked for
/// coarse structure — a ridge line, a painted terrace, a curtain of light. A
/// backdrop finer than the displacement is pushed through whole periods and
/// lands looking identical, and the glass then appears to do nothing.
final scenes = <SceneInfo>[
  SceneInfo(
    name: 'Lens',
    blurb:
        'Refraction across the whole surface. Drag it, and the ridge '
        'behind bends with it.',
    photo: 'assets/images/desert_dunes.jpg',
    panelBackdrop: const Color(0xFF674339),
    barBackdrop: const Color(0xFF9E532C),
    material: GlassMaterial.dome(),
  ),
  SceneInfo(
    name: 'Edge',
    blurb:
        "Apple's material bends only at the rim. Regular and clear, "
        'fitted to iOS 27 captures.',
    photo: 'assets/images/coastal_town.jpg',
    panelBackdrop: const Color(0xFF3F4A4A),
    barBackdrop: const Color(0xFF424237),
    material: GlassMaterial.regular(brightness: Brightness.dark),
  ),
  SceneInfo(
    name: 'Blend',
    blurb:
        'Two shapes, one distance field. Slide them together and they '
        'join through a neck.',
    photo: 'assets/images/northern_lights.jpg',
    panelBackdrop: const Color(0xFF29364C),
    barBackdrop: const Color(0xFF182831),
    material: GlassMaterial.dome(),
  ),
  SceneInfo(
    name: 'Motion',
    blurb:
        "Squash is read off the spring's own velocity, so it peaks when "
        'the surface is fastest.',
    photo: 'assets/images/tokyo_rain.jpg',
    panelBackdrop: const Color(0xFF482427),
    barBackdrop: const Color(0xFF56232A),
    material: GlassMaterial.dome(),
  ),
  SceneInfo(
    name: 'System',
    blurb:
        'Named surfaces, each resolving its own material — and the tier '
        'that decided what they render.',
    photo: 'assets/images/alpine_lake.jpg',
    panelBackdrop: const Color(0xFF676664),
    barBackdrop: const Color(0xFF494A4D),
    material: GlassMaterial.regular(brightness: Brightness.dark),
  ),
];

/// The layout every scene shares: the specimen owns the frame, the controls
/// sit at the bottom of it.
///
/// The specimen is centred in whatever is left after the control panel, which
/// is what keeps the interesting thing in the middle of the screen on a small
/// phone and a large one alike.
class SceneShell extends StatelessWidget {
  const SceneShell({
    required this.specimen,
    required this.controls,
    required this.code,
    required this.backdrop,
    this.extraControls,
    super.key,
  });

  /// The glass this scene exists to show.
  final Widget specimen;

  /// The scene's control row.
  final Widget controls;

  /// A second row, for the scenes that genuinely need two.
  ///
  /// Optional rather than a list, because two rows is the point at which a
  /// panel starts eating the specimen it exists to adjust, and a limit that
  /// has to be typed out is a limit somebody notices.
  final Widget? extraControls;

  /// The call that produced what is on screen, updated as the controls move.
  final String code;

  /// What is behind the control panel, for its own adaptation.
  final Color backdrop;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: Center(child: specimen)),
        const SizedBox(height: 16),
        // A sheet, not a navigation bar: this is a panel of controls over the
        // content, and the role carries the difference. A sheet also adapts
        // rather than flips, which is correct here — at this height the size
        // gate would demote a flipping role anyway.
        GlassSurface.sheet(
          backdrop: backdrop,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                controls,
                if (extraControls != null) ...[
                  const SizedBox(height: 8),
                  extraControls!,
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      code,
                      // Two lines rather than an ellipsis. A signature is the
                      // one string on screen a reader came for, and code
                      // wraps in an editor too.
                      maxLines: 2,
                      style: context.code.copyWith(color: context.inkTertiary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
