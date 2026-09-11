import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

/// One plain shape, big enough that the refraction at its edge is the only
/// thing to look at.
class StudioSpecimen extends StatelessWidget {
  const StudioSpecimen({super.key});

  static const double _side = 200;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: _side,
      child: KitGlassLayer(
        priority: GlassPriority.content,
        shape: GlassSuperellipse(radius: BorderRadius.all(Radius.circular(56))),
        child: SizedBox.expand(),
      ),
    );
  }
}
