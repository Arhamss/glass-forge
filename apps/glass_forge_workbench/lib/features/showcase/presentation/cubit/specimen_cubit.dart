import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/specimen_state.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/enums/showcase_shape.dart';

/// Drives the specimen screen: which shape and backdrop are shown, and
/// every knob on the live [GlassMaterial].
class SpecimenCubit extends Cubit<SpecimenState> {
  /// Creates the cubit, defaulting to the Apple-fitted dark regular
  /// material so the stage looks right before anyone touches a slider.
  SpecimenCubit()
    : super(
        SpecimenState(material: GlassMaterial.regular(brightness: Brightness.dark)),
      );

  /// Removes the native splash overlay. This screen is the app's landing
  /// destination, so nothing else calls [FlutterNativeSplash.remove].
  void init() => FlutterNativeSplash.remove();

  /// Picks the specimen's silhouette.
  void setShape(ShowcaseShape shape) => emit(state.copyWith(shape: shape));

  /// Picks the backdrop shown on the stage.
  void setBackdrop(GlassBackdrop backdrop) =>
      emit(state.copyWith(backdrop: backdrop));

  /// Replaces the whole material, e.g. with one of the Apple-fitted presets.
  void setMaterial(GlassMaterial material) =>
      emit(state.copyWith(material: material));

  /// Switches between [GlassVariant.regular] and [GlassVariant.clear].
  void setVariant(GlassVariant variant) =>
      _updateMaterial(state.material.copyWith(variant: variant));

  /// Sets [GlassMaterial.thickness].
  void setThickness(double value) =>
      _updateMaterial(state.material.copyWith(thickness: value));

  /// Sets [GlassMaterial.edgeRefraction].
  void setEdgeRefraction(double value) =>
      _updateMaterial(state.material.copyWith(edgeRefraction: value));

  /// Sets [GlassMaterial.refractionSpread].
  void setRefractionSpread(double value) =>
      _updateMaterial(state.material.copyWith(refractionSpread: value));

  /// Sets [GlassMaterial.frost].
  void setFrost(double value) =>
      _updateMaterial(state.material.copyWith(frost: value));

  /// Sets [GlassMaterial.chromaticAberration].
  void setChromaticAberration(double value) =>
      _updateMaterial(state.material.copyWith(chromaticAberration: value));

  /// Sets [GlassMaterial.saturation].
  void setSaturation(double value) =>
      _updateMaterial(state.material.copyWith(saturation: value));

  /// Sets [GlassMaterial.highlight].
  void setHighlight(double value) =>
      _updateMaterial(state.material.copyWith(highlight: value));

  /// Sets [GlassMaterial.contour].
  void setContour(double value) =>
      _updateMaterial(state.material.copyWith(contour: value));

  /// Sets [GlassMaterial.tintOpacity].
  void setTintOpacity(double value) =>
      _updateMaterial(state.material.copyWith(tintOpacity: value));

  /// Sets [GlassMaterial.tint].
  void setTint(Color color) =>
      _updateMaterial(state.material.copyWith(tint: color));

  /// Sets [GlassMaterial.lightDirection].
  void setLightDirection(Offset direction) =>
      _updateMaterial(state.material.copyWith(lightDirection: direction));

  void _updateMaterial(GlassMaterial material) =>
      emit(state.copyWith(material: material));
}
