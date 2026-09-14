import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/chrome.dart';
import 'package:glass_forge_example/src/scene.dart';
import 'package:glass_forge_example/src/theme.dart';

/// Apple's two materials, side by side over the same photograph.
///
/// Both are fitted against real iOS 27 captures rather than chosen by eye,
/// and the numbers are deliberately not rounded to look tidy — the regular
/// material's dark tint sits at 56% because that is where it measured.
///
/// `regular` adapts: tint, frost and saturation all move with the scheme, and
/// the switch below retunes it live. `clear` does not adapt at all — Apple is
/// explicit that it "does not have adaptive behaviors" — so it takes no
/// brightness and computes its dimming from sampled backdrop luminance in the
/// shader instead. Apple is equally explicit that the two "should never be
/// mixed" in one interface; they are mixed here because the difference is the
/// whole point of the scene.
///
/// Both specimens carry a letterform, because the difference between these
/// materials is not really a difference in texture. Regular exists to make a
/// label readable over anything. Clear exists for media-rich content where the
/// foreground is already bold and bright — and it shows, at this size, on the
/// small caption rather than on the big one.
class EdgeScene extends StatefulWidget {
  const EdgeScene({required this.info, super.key});

  final SceneInfo info;

  @override
  State<EdgeScene> createState() => _EdgeSceneState();
}

class _EdgeSceneState extends State<EdgeScene> {
  Brightness _brightness = Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return SceneShell(
      backdrop: widget.info.panelBackdrop,
      specimen: SizedBox(
        // Nothing like the size of a nav bar, but nowhere near the slab a
        // full-height panel becomes either. The fitted presets are tuned for
        // small surfaces over bright content: at 200 points the 27-point edge
        // band is still a quarter of the width and reads as a rim, where over
        // a whole screen it would be a hairline around a sheet of tint.
        height: 200,
        child: Row(
          children: [
            Expanded(
              child: _Specimen(
                label: 'regular',
                // An override, not the layer's material. The layer groups its
                // shapes by the material each asked for and pushes one
                // backdrop pass per group, so these two cost two passes
                // between them however many shapes played each part.
                material: GlassMaterial.regular(brightness: _brightness),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Specimen(
                label: 'clear',
                material: GlassMaterial.clear(),
              ),
            ),
          ],
        ),
      ),
      controls: SegmentedControl<Brightness>(
        options: Brightness.values,
        selected: _brightness,
        onChanged: (value) => setState(() => _brightness = value),
        labelOf: (value) => value == Brightness.dark ? 'Dark' : 'Light',
      ),
      code: 'GlassMaterial.regular(brightness: Brightness.'
          '${_brightness.name})',
    );
  }
}

class _Specimen extends StatelessWidget {
  const _Specimen({required this.label, required this.material});

  final String label;
  final GlassMaterial material;

  @override
  Widget build(BuildContext context) {
    return Glass(
      shape: const GlassSuperellipse(
        radius: BorderRadius.all(Radius.circular(40)),
      ),
      material: material,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              'Aa',
              style: context.display.copyWith(fontSize: 46, height: 1),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              // An explicit height, not an alignment on a bare Container:
              // that expands to fill the slot and swallows the specimen.
              height: 32,
              alignment: Alignment.center,
              color: Tone.captionScrim,
              child: GlassCaption(label),
            ),
          ),
        ],
      ),
    );
  }
}
