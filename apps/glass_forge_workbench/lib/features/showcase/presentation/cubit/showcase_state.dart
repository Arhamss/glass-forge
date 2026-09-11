import 'package:equatable/equatable.dart';
import 'package:glass_forge_workbench/features/showcase/data/models/place.dart';
import 'package:glass_forge_workbench/features/showcase/data/models/place_category.dart';
import 'package:glass_forge_workbench/features/showcase/data/place_catalog.dart';

class ShowcaseState extends Equatable {
  const ShowcaseState({
    this.category = PlaceCategory.forYou,
    this.savedIds = const {},
    this.query = '',
    this.isPlaying = false,
    this.hasUnreadAlerts = true,
  });

  final PlaceCategory category;
  final Set<String> savedIds;
  final String query;
  final bool isPlaying;
  final bool hasUnreadAlerts;

  bool isSaved(Place place) => savedIds.contains(place.id);

  /// The feed: the category's places, narrowed by the search query.
  List<Place> get visiblePlaces {
    final needle = query.trim().toLowerCase();
    return [
      for (final place in PlaceCatalog.places)
        if (_inCategory(place) &&
            (needle.isEmpty ||
                place.title.toLowerCase().contains(needle) ||
                place.region.toLowerCase().contains(needle)))
          place,
    ];
  }

  /// Saved places, nearest first.
  List<Place> get savedPlaces => [
    for (final place in PlaceCatalog.places)
      if (isSaved(place)) place,
  ]..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

  Place? get nearestSaved {
    final saved = savedPlaces;
    return saved.isEmpty ? null : saved.first;
  }

  bool get isSearching => query.trim().isNotEmpty;

  bool _inCategory(Place place) => switch (category) {
    PlaceCategory.forYou => true,
    PlaceCategory.nearby => place.isNearby,
    PlaceCategory.saved => isSaved(place),
  };

  ShowcaseState copyWith({
    PlaceCategory? category,
    Set<String>? savedIds,
    String? query,
    bool? isPlaying,
    bool? hasUnreadAlerts,
  }) {
    return ShowcaseState(
      category: category ?? this.category,
      savedIds: savedIds ?? this.savedIds,
      query: query ?? this.query,
      isPlaying: isPlaying ?? this.isPlaying,
      hasUnreadAlerts: hasUnreadAlerts ?? this.hasUnreadAlerts,
    );
  }

  @override
  List<Object?> get props => [
    category,
    savedIds,
    query,
    isPlaying,
    hasUnreadAlerts,
  ];
}
