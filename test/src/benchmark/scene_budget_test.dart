import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/benchmark/scene_budget.dart';

void main() {
  test('round-trips through JSON', () {
    const budget = SceneBudget(
      sceneId: 'shape_count_4',
      rasterP90Ms: 12.5,
      rasterP99Ms: 15,
      buildP90Ms: 6,
    );

    final restored = SceneBudget.fromJson(budget.toJson());

    expect(restored.sceneId, budget.sceneId);
    expect(restored.rasterP90Ms, budget.rasterP90Ms);
    expect(restored.rasterP99Ms, budget.rasterP99Ms);
    expect(restored.buildP90Ms, budget.buildP90Ms);
  });

  test('names the missing field rather than throwing a bare cast error', () {
    expect(
      () => SceneBudget.fromJson(const {
        'sceneId': 'shape_count_4',
        'rasterP90Ms': 12.5,
        // rasterP99Ms and buildP90Ms deliberately omitted.
      }),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('rasterP99Ms'),
        ),
      ),
    );
  });

  test('rejects a non-string sceneId with a named error', () {
    expect(
      () => SceneBudget.fromJson(const {
        'sceneId': 42,
        'rasterP90Ms': 1,
        'rasterP99Ms': 1,
        'buildP90Ms': 1,
      }),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('sceneId'),
        ),
      ),
    );
  });

  test('accepts an integer where a double is expected', () {
    // budgets.json is hand-edited; a reviewer writing "16" instead of "16.0"
    // must not fail to parse.
    final budget = SceneBudget.fromJson(const {
      'sceneId': 's',
      'rasterP90Ms': 16,
      'rasterP99Ms': 20,
      'buildP90Ms': 8,
    });
    expect(budget.rasterP90Ms, 16.0);
  });
}
