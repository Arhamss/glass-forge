import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/benchmark/benchmark_run_mode.dart';
import 'package:glass_forge/src/benchmark/frame_time_stats.dart';

/// One scene's measured frame-time percentiles, with the honesty context a
/// bare number cannot carry on its own.
///
/// [runMode] travels with every report rather than being a side channel the
/// caller has to remember to check, because a report that gets forwarded,
/// logged or serialised without it is exactly how a debug-mode number ends
/// up quoted as a real one.
@immutable
class BenchmarkFrameReport {
  /// Creates a report.
  const BenchmarkFrameReport({
    required this.sceneId,
    required this.runMode,
    required this.build,
    required this.raster,
    required this.total,
    this.notes,
  });

  /// Which `BenchmarkScene` this report came from.
  final String sceneId;

  /// The compilation mode active while this was captured.
  final BenchmarkRunMode runMode;

  /// UI-thread build-phase percentiles.
  final FrameTimeStats build;

  /// Raster-thread percentiles.
  final FrameTimeStats raster;

  /// Vsync-to-raster-finish percentiles -- the end-to-end span.
  final FrameTimeStats total;

  /// The scene's own description, carried through so a report is legible on
  /// its own without cross-referencing the scene catalog.
  final String? notes;

  /// This report as JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'sceneId': sceneId,
    'runMode': runMode.name,
    'trustworthy': runMode.isTrustworthy,
    'build': build.toJson(),
    'raster': raster.toJson(),
    'total': total.toJson(),
    if (notes != null) 'notes': notes,
  };

  /// A multi-line, human-readable block.
  ///
  /// The [BenchmarkRunMode.warningBanner] is baked into the string itself
  /// rather than left for the caller to prepend, so nothing that prints this
  /// report can forget to carry the warning along with it.
  String toHumanReadable() {
    final buffer = StringBuffer()
      ..writeln('$sceneId  [${runMode.name}]')
      ..writeln('  build:  $build')
      ..writeln('  raster: $raster')
      ..writeln('  total:  $total');
    if (notes != null) {
      buffer.writeln('  ($notes)');
    }
    if (!runMode.isTrustworthy) {
      buffer.writeln('  ${runMode.warningBanner}');
    }
    return buffer.toString();
  }
}
