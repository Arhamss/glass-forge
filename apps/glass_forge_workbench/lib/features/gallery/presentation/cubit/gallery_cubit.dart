import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/cubit/gallery_state.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_surface_role_extensions.dart';

/// Drives the gallery: which role is on the stage, what is behind it, and
/// how big it is drawn.
class GalleryCubit extends Cubit<GalleryState> {
  /// Creates the cubit.
  GalleryCubit() : super(const GalleryState());

  /// Puts [role] on the stage, at the size that role really ships at.
  ///
  /// Carrying the previous role's height over would show a 180 pt button
  /// and a 44 pt sheet, and the flip gate reads exactly that number — so
  /// the screen would be answering a question nobody asked.
  void setRole(GlassSurfaceRole role) =>
      emit(state.copyWith(role: role, shortSide: role.naturalShortSide));

  /// Picks what the surfaces are drawn over, and told they are over.
  void setBackdrop(GlassBackdrop backdrop) =>
      emit(state.copyWith(backdrop: backdrop));

  /// Sets the height every demonstration surface is drawn at.
  void setShortSide(double value) => emit(state.copyWith(shortSide: value));
}
