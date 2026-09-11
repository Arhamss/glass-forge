import 'dart:math' as math;

import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/specimen_cubit.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/specimen_state.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/groups/geometry_group.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/groups/light_group.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/groups/optics_group.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/groups/shape_variant_group.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/groups/tint_group.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/specimen_stage.dart';
import 'package:glass_forge_workbench/utils/enums/showcase_shape.dart';

/// The workbench's landing screen: a live glass specimen on a stage with a
/// real backdrop, and a solid instrument panel exposing every material
/// knob `glass_forge` has.
///
/// Per docs/design/workbench-design.md, the instrument is never glass —
/// only the stage's one specimen is, captured by a single `GlassLayer`
/// wrapping it.
class SpecimenView extends StatelessWidget {
  /// Creates the view.
  const SpecimenView({super.key});

  /// Fraction of the stage's shorter dimension the specimen occupies.
  ///
  /// Refraction only reads at a boundary — the eye needs undistorted
  /// backdrop next to the distorted backdrop to see the bend. Kept well
  /// under 1.0 so generous backdrop stays visible around the specimen.
  static const _specimenSizeFraction = 0.5;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SpecimenCubit()..init(),
      child: Scaffold(
        backgroundColor: AppColors.stageGround,
        body: Column(
          children: [
            Expanded(
              flex: 55,
              child: BlocBuilder<SpecimenCubit, SpecimenState>(
                buildWhen: (previous, current) =>
                    previous.shape != current.shape ||
                    previous.material != current.material ||
                    previous.backdrop != current.backdrop,
                builder: (context, state) {
                  final cubit = context.read<SpecimenCubit>();
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final specimenSize =
                          math.min(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ) *
                          _specimenSizeFraction;
                      return GlassLayer(
                        material: state.material,
                        child: SpecimenStage(
                          backdrop: state.backdrop,
                          onBackdropChanged: cubit.setBackdrop,
                          child: SizedBox(
                            width: specimenSize,
                            height: specimenSize,
                            child: Glass(shape: state.shape.toGlassShape()),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Expanded(
              flex: 45,
              child: ColoredBox(
                color: AppColors.stageGround,
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BlocBuilder<SpecimenCubit, SpecimenState>(
                        buildWhen: (previous, current) =>
                            previous.shape != current.shape ||
                            previous.material != current.material,
                        builder: (context, state) {
                          final cubit = context.read<SpecimenCubit>();
                          return ShapeVariantGroup(
                            shape: state.shape,
                            variant: state.material.variant,
                            onShapeChanged: cubit.setShape,
                            onVariantChanged: cubit.setVariant,
                            onPresetSelected: cubit.setMaterial,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      BlocBuilder<SpecimenCubit, SpecimenState>(
                        buildWhen: (previous, current) =>
                            previous.material != current.material,
                        builder: (context, state) {
                          final cubit = context.read<SpecimenCubit>();
                          return GeometryGroup(
                            thickness: state.material.thickness,
                            edgeRefraction: state.material.edgeRefraction,
                            refractionSpread: state.material.refractionSpread,
                            onThicknessChanged: cubit.setThickness,
                            onEdgeRefractionChanged: cubit.setEdgeRefraction,
                            onRefractionSpreadChanged:
                                cubit.setRefractionSpread,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      BlocBuilder<SpecimenCubit, SpecimenState>(
                        buildWhen: (previous, current) =>
                            previous.material != current.material,
                        builder: (context, state) {
                          final cubit = context.read<SpecimenCubit>();
                          return OpticsGroup(
                            frost: state.material.frost,
                            chromaticAberration:
                                state.material.chromaticAberration,
                            saturation: state.material.saturation,
                            onFrostChanged: cubit.setFrost,
                            onChromaticAberrationChanged:
                                cubit.setChromaticAberration,
                            onSaturationChanged: cubit.setSaturation,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      BlocBuilder<SpecimenCubit, SpecimenState>(
                        buildWhen: (previous, current) =>
                            previous.material != current.material,
                        builder: (context, state) {
                          final cubit = context.read<SpecimenCubit>();
                          return LightGroup(
                            highlight: state.material.highlight,
                            contour: state.material.contour,
                            lightDirection: state.material.lightDirection,
                            onHighlightChanged: cubit.setHighlight,
                            onContourChanged: cubit.setContour,
                            onLightDirectionChanged: cubit.setLightDirection,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      BlocBuilder<SpecimenCubit, SpecimenState>(
                        buildWhen: (previous, current) =>
                            previous.material != current.material,
                        builder: (context, state) {
                          final cubit = context.read<SpecimenCubit>();
                          return TintGroup(
                            tintOpacity: state.material.tintOpacity,
                            tint: state.material.tint,
                            onTintOpacityChanged: cubit.setTintOpacity,
                            onTintChanged: cubit.setTint,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Sampling probe',
                        onPressed: () =>
                            context.pushNamed(AppRouteNames.samplingProbe),
                        backgroundColor: AppColors.transparent,
                        textColor: AppColors.stageForegroundMuted,
                        splashColor: AppColors.transparent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        padding: EdgeInsetsDirectional.zero,
                        outsidePadding: EdgeInsetsDirectional.zero,
                        centerContent: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
