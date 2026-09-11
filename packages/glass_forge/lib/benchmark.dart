/// The device benchmark harness for glass_forge.
///
/// Deliberately separate from `package:glass_forge/glass_forge.dart` --
/// nothing exported here is part of the rendering API ordinary consumers of
/// the package use. Import this directly from a benchmark runner, the way
/// `glass_forge_workbench`'s sampling probe imports `debug.dart` for its own
/// tooling needs.
///
/// See `docs/superpowers/specs/2026-09-10-glass-forge-architecture-design.md`
/// §7: "The harness is not a deliverable that comes after -- tiers cannot be
/// tuned without measurement, and performance claims made without it are
/// guesses."
library;

export 'src/benchmark/benchmark_budgets.dart';
export 'src/benchmark/benchmark_frame_report.dart';
export 'src/benchmark/benchmark_gate.dart';
export 'src/benchmark/benchmark_run_mode.dart';
export 'src/benchmark/benchmark_warmup.dart';
export 'src/benchmark/frame_time_recorder.dart';
export 'src/benchmark/frame_time_stats.dart';
export 'src/benchmark/scene_budget.dart';
export 'src/benchmark/scenes/benchmark_scene.dart';
export 'src/benchmark/scenes/glass_benchmark_scenes.dart';
