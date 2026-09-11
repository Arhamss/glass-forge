import 'package:flutter/foundation.dart';

/// A percentile summary of a batch of frame-time samples.
///
/// Deliberately has no `mean`. A mean of 8ms can hide a p99 that drops a
/// frame every hundred, and a mean dragged up by one real stutter can hide
/// an otherwise-smooth p50 -- either way the average answers a question
/// nobody asked. Percentiles, plus the true [worst], are what a jank budget
/// actually needs: p50 for the typical frame, p90 and p99 for how bad the
/// tail gets, and worst for the single frame a user might have actually
/// seen drop.
@immutable
class FrameTimeStats {
  const FrameTimeStats._({
    required this.sampleCount,
    required this.p50,
    required this.p90,
    required this.p99,
    required this.worst,
  });

  /// Computes percentiles over [samples].
  ///
  /// Order does not matter; this sorts its own copy and leaves [samples]
  /// untouched.
  ///
  /// Throws [ArgumentError] on an empty list. A percentile of zero samples
  /// is not zero milliseconds, it is undefined -- reporting zero would read
  /// as an excellent real measurement instead of "nothing was captured".
  factory FrameTimeStats.of(List<Duration> samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(
        samples,
        'samples',
        'FrameTimeStats needs at least one sample; an empty list has no '
            'percentiles to report.',
      );
    }
    final sorted = List<Duration>.of(samples)..sort();
    return FrameTimeStats._(
      sampleCount: sorted.length,
      p50: _percentile(sorted, 50),
      p90: _percentile(sorted, 90),
      p99: _percentile(sorted, 99),
      worst: sorted.last,
    );
  }

  /// How many samples this summary was computed from.
  final int sampleCount;

  /// The median frame.
  final Duration p50;

  /// The frame at the 90th percentile -- one in ten frames is at least this
  /// slow.
  final Duration p90;

  /// The frame at the 99th percentile -- one in a hundred frames is at
  /// least this slow.
  final Duration p99;

  /// The single slowest frame in the batch.
  final Duration worst;

  /// Nearest-rank percentile: the smallest sample at or beyond the point
  /// where [percent] of the distribution has been covered.
  ///
  /// Nearest-rank rather than linear interpolation on purpose -- it always
  /// names an actual sample that was actually measured, never a value
  /// invented between two real ones, and it is deterministic on ties, which
  /// matters for a gate that must produce the same verdict on the same
  /// input every time.
  static Duration _percentile(List<Duration> sorted, num percent) {
    final rank = (percent / 100 * sorted.length).ceil().clamp(
      1,
      sorted.length,
    );
    return sorted[rank - 1];
  }

  /// This summary as milliseconds, for reports and JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'sampleCount': sampleCount,
    'p50Ms': _ms(p50),
    'p90Ms': _ms(p90),
    'p99Ms': _ms(p99),
    'worstMs': _ms(worst),
  };

  static double _ms(Duration d) => d.inMicroseconds / 1000;

  @override
  String toString() =>
      'p50=${_ms(p50).toStringAsFixed(2)}ms '
      'p90=${_ms(p90).toStringAsFixed(2)}ms '
      'p99=${_ms(p99).toStringAsFixed(2)}ms '
      'worst=${_ms(worst).toStringAsFixed(2)}ms '
      '(n=$sampleCount)';
}
