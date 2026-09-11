import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/features/showcase/data/models/place_category.dart';
import 'package:glass_forge_workbench/features/showcase/data/place_catalog.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_cubit.dart';

void main() {
  group('ShowcaseCubit', () {
    test('For you shows every place', () {
      final cubit = ShowcaseCubit();
      expect(cubit.state.visiblePlaces, PlaceCatalog.places);
    });

    test('Nearby shows only nearby places', () {
      final cubit = ShowcaseCubit()..setCategory(PlaceCategory.nearby);
      expect(cubit.state.visiblePlaces, isNotEmpty);
      expect(cubit.state.visiblePlaces.every((p) => p.isNearby), isTrue);
    });

    test('Saved is empty until something is saved, then shows it', () {
      final cubit = ShowcaseCubit()..setCategory(PlaceCategory.saved);
      expect(cubit.state.visiblePlaces, isEmpty);

      final place = PlaceCatalog.places[2];
      cubit.toggleSaved(place);
      expect(cubit.state.visiblePlaces, [place]);
      expect(cubit.state.isSaved(place), isTrue);

      cubit.toggleSaved(place);
      expect(cubit.state.visiblePlaces, isEmpty);
    });

    test('the query matches title or region, ignoring case', () {
      final cubit = ShowcaseCubit()..setQuery('  ITALY ');
      expect(
        cubit.state.visiblePlaces.map((p) => p.id),
        containsAll(<String>['braies', 'riomaggiore']),
      );
      cubit.setQuery('yokoch');
      expect(cubit.state.visiblePlaces.single.id, 'omoide');
    });

    test('saved places come nearest first, and name the nearest', () {
      final far = PlaceCatalog.places.firstWhere((p) => p.id == 'chebbi');
      final near = PlaceCatalog.places.firstWhere((p) => p.id == 'columbia');
      final cubit = ShowcaseCubit()
        ..toggleSaved(far)
        ..toggleSaved(near);

      expect(cubit.state.savedPlaces, [near, far]);
      expect(cubit.state.nearestSaved, near);
    });

    test('opening notifications clears the unread badge', () {
      final cubit = ShowcaseCubit();
      expect(cubit.state.hasUnreadAlerts, isTrue);
      cubit.markAlertsRead();
      expect(cubit.state.hasUnreadAlerts, isFalse);
    });

    test('play toggles', () {
      final cubit = ShowcaseCubit()..togglePlaying();
      expect(cubit.state.isPlaying, isTrue);
    });
  });
}
