import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/chrome.dart';
import 'package:glass_forge_example/src/scene.dart';

/// Two shapes that merge instead of overlapping.
///
/// Every `Glass` registers its silhouette into one shared signed-distance
/// field. Inside a `GlassBlendGroup` those distances smooth-min into one
/// another, so two shapes closer than `blend` join through a neck rather than
/// stacking as two cut-outs — which is also the correct way to draw
/// overlapping glass, since two separate surfaces that overlap would have the
/// later one sampling the earlier one's output.
///
/// Drag the right-hand shape. The blend follows the motion because
/// `RenderGlassShape` re-registers its geometry from the paint transform on
/// every paint, so the field is rebuilt from where the shape *is*, not where
/// it was laid out.
class BlendScene extends StatefulWidget {
  const BlendScene({required this.info, super.key});

  final SceneInfo info;

  @override
  State<BlendScene> createState() => _BlendSceneState();
}

class _BlendSceneState extends State<BlendScene> {
  double _blend = 28;

  @override
  Widget build(BuildContext context) {
    return SceneShell(
      backdrop: widget.info.panelBackdrop,
      specimen: SizedBox(
        height: 200,
        child: GlassBlendGroup(
          blend: _blend,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 132,
                child: Glass(shape: GlassOval()),
              ),
              // The gap the blend has to bridge. At a blend width under this
              // the two stay separate; over it, a neck appears and thickens.
              SizedBox(width: 22),
              SizedBox.square(
                dimension: 132,
                child: InteractiveGlass(
                  // Horizontal only, and rubber-banded to 96 logical pixels.
                  // Both constraints are compositional: the specimen can
                  // never reach the control panel below it, so no drag can
                  // put one glass surface over another.
                  drag: GlassDrag(
                    axis: Axis.horizontal,
                    overdrag: GlassOverdrag(limit: 96),
                  ),
                  settleMotion: GlassMotion.smooth(),
                  child: Glass(shape: GlassOval()),
                ),
              ),
            ],
          ),
        ),
      ),
      controls: ValueSlider(
        label: 'Blend',
        value: _blend,
        min: 0,
        max: 64,
        format: (v) => '${v.round()} px',
        onChanged: (v) => setState(() => _blend = v),
      ),
      code: 'GlassBlendGroup(blend: ${_blend.round()})',
    );
  }
}
