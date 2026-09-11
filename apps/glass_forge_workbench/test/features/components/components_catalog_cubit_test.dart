import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/components_catalog_cubit.dart';
import 'package:glass_forge_workbench/l10n/gen/app_localizations_en.dart';
import 'package:glass_forge_workbench/l10n/localization_service.dart';
import 'package:glass_forge_workbench/utils/enums/component_family.dart';
import 'package:glass_forge_workbench/utils/enums/component_id.dart';

void main() {
  setUpAll(() => Localization.update(AppLocalizationsEn()));

  group('ComponentsCatalogCubit', () {
    test('lists every component, grouped by family in order', () {
      final groups = ComponentsCatalogCubit().state.groups;
      expect(groups.map((g) => g.$1), ComponentFamily.values);
      expect(groups.expand((g) => g.$2).toList(), ComponentId.values);
    });

    test('the query matches a title or a summary, ignoring case', () {
      final cubit = ComponentsCatalogCubit()..setQuery('SHEET');
      final found = cubit.state.groups.expand((g) => g.$2).toList();
      expect(found, [ComponentId.bottomSheet]);

      cubit.setQuery('lens');
      expect(cubit.state.groups.expand((g) => g.$2), [ComponentId.slider]);
    });

    test('families with no match drop out, and nothing matches nothing', () {
      final cubit = ComponentsCatalogCubit()..setQuery('capsule');
      expect(cubit.state.groups.every((group) => group.$2.isNotEmpty), isTrue);
      cubit.setQuery('zzzz');
      expect(cubit.state.groups, isEmpty);
    });
  });
}
