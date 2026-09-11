import 'package:glass_forge_workbench/l10n/localization_service.dart';

enum PlaceCategory { forYou, nearby, saved }

extension PlaceCategoryX on PlaceCategory {
  String get label => switch (this) {
    PlaceCategory.forYou => Localization.categoryForYou,
    PlaceCategory.nearby => Localization.categoryNearby,
    PlaceCategory.saved => Localization.categorySaved,
  };
}
