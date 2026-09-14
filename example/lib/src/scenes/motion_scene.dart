import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/chrome.dart';
import 'package:glass_forge_example/src/scene.dart';
import 'package:glass_forge_example/src/theme.dart';

/// Drag it, throw it, let it come home.
///
/// Springs are written the way Apple writes them — a duration and a bounce,
/// never a stiffness and a damping — and `GlassMotion.bouncy`, `.snappy` and
/// `.smooth` resolve to the same numbers SwiftUI's own presets do.
///
/// The deformation is the part worth watching. It is not a second animation
/// running alongside the translation; it is read straight off the translation
/// spring's live velocity, so it is largest exactly when the surface is
/// moving fastest and gone the instant it stops. It also stretches *along*
/// the velocity and compresses across it by the reciprocal, which conserves
/// area — without that, a fast surface looks like it is growing.
///
/// Under the platform's Reduce Motion setting every spring here collapses to
/// an instant settle and the deformation stops entirely. The surface still
/// answers the pointer; it just stops springing about it.
class MotionScene extends StatefulWidget {
  const MotionScene({required this.info, super.key});

  final SceneInfo info;

  @override
  State<MotionScene> createState() => _MotionSceneState();
}

class _MotionSceneState extends State<MotionScene> {
  static const _springs = <String, GlassMotion>{
    'Bouncy': GlassMotion.bouncy(),
    'Snappy': GlassMotion.snappy(),
    'Smooth': GlassMotion.smooth(),
  };

  String _spring = 'Bouncy';
  double _stretch = 1.18;

  @override
  Widget build(BuildContext context) {
    return SceneShell(
      backdrop: widget.info.panelBackdrop,
      specimen: SizedBox.square(
        dimension: 168,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Where the surface springs back to. Painted, and inside the
            // layer, so it is drawn rather than refracted — the layer
            // captures what is behind *it*, and this is not.
            DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(46)),
                  side: BorderSide(color: context.inkHairline),
                ),
              ),
            ),
            InteractiveGlass(
              drag: const GlassDrag(
                // Rubber-banded to 96 logical pixels, which the curve
                // approaches and never reaches. That is what makes the
                // composition safe by construction: however long the gesture
                // runs, the specimen cannot travel far enough to land on the
                // control panel and put glass over glass.
                overdrag: GlassOverdrag(limit: 96),
              ),
              settleMotion: _springs[_spring]!,
              jiggle: GlassJiggle(maxStretch: _stretch),
              child: const Glass(
                shape: GlassSuperellipse(
                  radius: BorderRadius.all(Radius.circular(46)),
                ),
              ),
            ),
          ],
        ),
      ),
      controls: SegmentedControl<String>(
        options: _springs.keys.toList(),
        selected: _spring,
        onChanged: (name) => setState(() => _spring = name),
        labelOf: (name) => name,
      ),
      extraControls: ValueSlider(
        label: 'Stretch',
        value: _stretch,
        min: 1,
        max: 1.4,
        format: (v) => '${v.toStringAsFixed(2)}x',
        onChanged: (v) => setState(() => _stretch = v),
      ),
      code: 'GlassJiggle(maxStretch: ${_stretch.toStringAsFixed(2)})',
    );
  }
}
