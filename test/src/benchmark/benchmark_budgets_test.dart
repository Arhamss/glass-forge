import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/benchmark/benchmark_budgets.dart';

void main() {
  test('parses every scene in the file, keyed by sceneId', () {
    const source = '''
    {
      "_provenance": "seed values, ignored by the parser",
      "scenes": [
        {"sceneId": "a", "rasterP90Ms": 10, "rasterP99Ms": 14, "buildP90Ms": 5},
        {"sceneId": "b", "rasterP90Ms": 11, "rasterP99Ms": 15, "buildP90Ms": 6}
      ]
    }
    ''';

    final budgets = BenchmarkBudgets.fromJsonString(source);

    expect(budgets.sceneIds, containsAll(<String>['a', 'b']));
    expect(budgets['a']!.rasterP90Ms, 10);
    expect(budgets['b']!.buildP90Ms, 6);
  });

  test('a scene with no budget returns null, not a default', () {
    // A missing budget must be visibly missing to the gate -- silently
    // treating it as "no ceiling" would let an ungated scene regress
    // forever without anything ever failing.
    const source = '{"scenes": []}';
    final budgets = BenchmarkBudgets.fromJsonString(source);

    expect(budgets['unknown_scene'], isNull);
  });

  test('rejects a file with no top-level object', () {
    expect(
      () => BenchmarkBudgets.fromJsonString('[]'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a file missing the scenes array', () {
    expect(
      () => BenchmarkBudgets.fromJsonString('{}'),
      throwsA(isA<FormatException>()),
    );
  });
}
