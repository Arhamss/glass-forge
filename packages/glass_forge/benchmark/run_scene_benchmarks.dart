// The glass_forge scene-benchmark runner.
//
// This is a real, runnable Flutter app entry point -- not a script. Frame
// timing only exists once the engine actually rasterises, so this has to
// run inside a live `flutter run`, on a device or a desktop target, with the
// scheduler and raster thread doing real work. It cannot run under
// `flutter test`; `AutomatedTestWidgetsFlutterBinding` never drives a real
// raster thread, so it would produce numbers that measure nothing -- see the
// package's own build report for why that risk mattered enough to call out.
//
// Usage, from `packages/glass_forge/`:
//
//   flutter run --profile -d macos -t benchmark/run_scene_benchmarks.dart
//
// Any `-d <device>` works; profile mode is what makes the result trustworthy
// -- see `BenchmarkRunMode`. The run prints one block per scene as it goes,
// then a PASS/FAIL line per scene once every scene has been measured, and
// exits non-zero if any scene exceeded its `budgets.json` budget. Debug-mode
// runs print every measurement but skip the gate entirely: a debug number is
// never presentable as a pass or a fail.
//
// Reading `budgets.json` uses `dart:io`, resolved relative to the process's
// working directory -- true for desktop targets launched from
// `packages/glass_forge/`, which is the intended invocation. A mobile
// device's filesystem is not this repository's, so gating does not work
// there yet; mobile runs still print every scene's measured percentiles,
// which is the harness's other job. Bundling `budgets.json` as a Flutter
// asset would fix that, at the cost of every consumer of this package
// shipping a benchmark budget file in their app -- not worth it until a
// mobile-gated CI lane actually exists.

import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/benchmark.dart';

/// How long a scene runs unmeasured before recording starts, so the very
/// first layout pass and any late shader pipeline-variant compile do not
/// count against its steady-state percentiles.
const Duration _warmUpWindow = Duration(seconds: 2);

/// How long a scene is measured for once recording starts.
const Duration _measureWindow = Duration(seconds: 4);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final mode = BenchmarkRunMode.current();
  debugPrint('glass_forge scene benchmarks -- run mode: ${mode.name}');
  if (!mode.isTrustworthy) {
    debugPrint(mode.warningBanner);
  }

  await warmUpGlassForgeShaders();

  final reports = <BenchmarkFrameReport>[];
  for (final scene in glassBenchmarkScenes) {
    debugPrint('--- ${scene.id}: ${scene.description}');
    final recorder = FrameTimeRecorder();

    runApp(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: scene.build),
      ),
    );
    await Future<void>.delayed(_warmUpWindow);

    SchedulerBinding.instance.addTimingsCallback(recorder.recordFrameTimings);
    await Future<void>.delayed(_measureWindow);
    SchedulerBinding.instance.removeTimingsCallback(
      recorder.recordFrameTimings,
    );

    final report = recorder.summarize(
      sceneId: scene.id,
      notes: scene.description,
    );
    reports.add(report);
    debugPrint(report.toHumanReadable());
  }

  await _gate(reports, mode);
}

Future<void> _gate(
  List<BenchmarkFrameReport> reports,
  BenchmarkRunMode mode,
) async {
  if (!mode.isTrustworthy) {
    debugPrint(
      'No regression verdict: this run was debug mode. Re-run with '
      '`flutter run --profile` (or `--release`) before trusting a gate '
      'result.',
    );
    return;
  }

  final BenchmarkBudgets budgets;
  try {
    final source = await File('benchmark/budgets.json').readAsString();
    budgets = BenchmarkBudgets.fromJsonString(source);
  } on Object catch (error) {
    debugPrint(
      'Could not load benchmark/budgets.json ($error). Run this from '
      "packages/glass_forge/, or see this file's header for why mobile "
      'targets cannot read it yet.',
    );
    exit(2);
  }

  var failed = false;
  for (final report in reports) {
    final budget = budgets[report.sceneId];
    if (budget == null) {
      debugPrint(
        'No budget for scene "${report.sceneId}" -- add one to '
        'benchmark/budgets.json before this scene can gate.',
      );
      continue;
    }
    final result = BenchmarkGate.evaluate(report, budget);
    if (result.passed) {
      debugPrint('PASS ${report.sceneId}');
      continue;
    }
    failed = true;
    debugPrint('FAIL ${report.sceneId}');
    for (final violation in result.violations) {
      debugPrint('  - $violation');
    }
  }

  exit(failed ? 1 : 0);
}
