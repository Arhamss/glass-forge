import 'dart:async';

import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/house_glass/presentation/cubit/house_glass_cubit.dart';
import 'package:glass_forge_workbench/features/house_glass/presentation/cubit/house_glass_state.dart';
import 'package:glass_forge_workbench/utils/helpers/glass_material_tween.dart';
import 'package:glass_forge_workbench/utils/helpers/reduce_motion.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/house_glass.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_zones.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_zones_scope.dart';

/// Everything the glass kit needs from above: the house material, the zone
/// registry that keeps the screen to one backdrop pass per point, and the
/// Reduce Transparency setting that turns every kit surface static.
class GlassKitRoot extends StatefulWidget {
  const GlassKitRoot({required this.child, super.key});

  final Widget child;

  @override
  State<GlassKitRoot> createState() => _GlassKitRootState();
}

class _GlassKitRootState extends State<GlassKitRoot> {
  final GlassZones _zones = GlassZones();
  final AccessibilitySignalSource _accessibility = AccessibilitySignalSource();

  @override
  void initState() {
    super.initState();
    _accessibility.addListener(_syncTransparency);
    unawaited(_accessibility.start());
  }

  void _syncTransparency() =>
      _zones.forceStatic = _accessibility.value.reduceTransparency;

  @override
  void dispose() {
    _accessibility
      ..removeListener(_syncTransparency)
      ..dispose();
    _zones.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zoned = GlassZonesScope(zones: _zones, child: widget.child);
    return BlocBuilder<HouseGlassCubit, HouseGlassState>(
      buildWhen: (previous, current) => previous.material != current.material,
      // A preset morphs every glass surface in the app into the new one. A
      // slider drag is already continuous, so it applies at once rather
      // than trailing the finger.
      builder: (context, state) => TweenAnimationBuilder<GlassMaterial>(
        tween: GlassMaterialTween(end: state.material),
        duration: state.preset != null && !context.reduceMotion
            ? AppMotion.presetTween
            : Duration.zero,
        curve: AppMotion.selectCurve,
        builder: (context, material, child) =>
            HouseGlass(material: material, child: child!),
        child: zoned,
      ),
    );
  }
}
