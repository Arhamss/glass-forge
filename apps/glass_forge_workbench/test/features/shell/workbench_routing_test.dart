import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/go_router/exports.dart';
import 'package:glass_forge_workbench/utils/enums/lab_tool.dart';
import 'package:glass_forge_workbench/utils/enums/workbench_tab.dart';

void main() {
  final configuration = AppRouter.router.configuration;

  test('the app opens on the Showcase', () {
    expect(
      AppRouter.router.routeInformationProvider.value.uri.path,
      AppRoutes.showcase,
    );
  });

  test('every tab is a route', () {
    for (final tab in WorkbenchTab.values) {
      expect(
        configuration.findMatch(Uri.parse(tab.path)).matches,
        isNotEmpty,
        reason: tab.name,
      );
    }
  });

  test('every Lab tool has a named route under the Lab', () {
    for (final tool in LabTool.values) {
      final location = configuration.namedLocation(tool.routeName);
      expect(location, startsWith('${AppRoutes.lab}/'), reason: tool.name);
      expect(configuration.findMatch(Uri.parse(location)).matches, isNotEmpty);
    }
  });
}
