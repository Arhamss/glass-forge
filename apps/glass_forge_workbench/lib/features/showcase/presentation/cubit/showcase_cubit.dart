import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glass_forge_workbench/features/showcase/data/models/place.dart';
import 'package:glass_forge_workbench/features/showcase/data/models/place_category.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_state.dart';

class ShowcaseCubit extends Cubit<ShowcaseState> {
  ShowcaseCubit() : super(const ShowcaseState());

  void setCategory(PlaceCategory category) =>
      emit(state.copyWith(category: category));

  void setQuery(String query) => emit(state.copyWith(query: query));

  /// Clears whatever is narrowing the feed, for an empty state's way out.
  void showEverything() =>
      emit(state.copyWith(category: PlaceCategory.forYou, query: ''));

  void toggleSaved(Place place) {
    final saved = {...state.savedIds};
    if (!saved.remove(place.id)) saved.add(place.id);
    emit(state.copyWith(savedIds: saved));
  }

  void togglePlaying() => emit(state.copyWith(isPlaying: !state.isPlaying));

  void markAlertsRead() => emit(state.copyWith(hasUnreadAlerts: false));
}
