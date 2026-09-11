import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/workbench_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the rail index and the router branch order are the same thing', () {
    // `WorkbenchRail` switches branches by enum index. Nothing in the
    // language ties that to the order the branches are declared in, so it
    // is tied here instead: get these out of step and every tab opens the
    // wrong screen.
    final shell = AppRouter.router.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;

    expect(shell.branches, hasLength(WorkbenchSection.values.length));
    for (final section in WorkbenchSection.values) {
      final route = shell.branches[section.index].routes.single as GoRoute;
      expect(route.path, section.path, reason: section.label);
    }
  });

  test('every section is reachable without signing in', () {
    // The workbench has nothing behind a login, and a section missing from
    // the public list would bounce to the login screen on first tap.
    for (final section in WorkbenchSection.values) {
      expect(
        AppRouter.router.configuration.findMatch(Uri.parse(section.path)),
        isNotNull,
        reason: section.label,
      );
    }
  });
}
