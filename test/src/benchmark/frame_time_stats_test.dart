import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/benchmark/frame_time_stats.dart';

void main() {
  test('rejects an empty sample list', () {
    // A percentile of nothing is undefined, not zero. Returning zero would
    // read as an excellent measurement instead of "nothing was captured".
    expect(() => FrameTimeStats.of(const <Duration>[]), throwsArgumentError);
  });

  test('nearest-rank percentiles over an evenly spaced batch', () {
    // 1ms..10ms. ceil(0.50*10)=5 -> index 4 (5ms); ceil(0.90*10)=9 -> index
    // 8 (9ms); ceil(0.99*10)=10 -> index 9 (10ms, same as worst).
    final samples = [
      for (var ms = 1; ms <= 10; ms++) Duration(milliseconds: ms),
    ];
    final stats = FrameTimeStats.of(samples);

    expect(stats.sampleCount, 10);
    expect(stats.p50, const Duration(milliseconds: 5));
    expect(stats.p90, const Duration(milliseconds: 9));
    expect(stats.p99, const Duration(milliseconds: 10));
    expect(stats.worst, const Duration(milliseconds: 10));
  });

  test('order of the input does not matter', () {
    final ascending = [
      for (var ms = 1; ms <= 10; ms++) Duration(milliseconds: ms),
    ];
    final shuffled = ascending.reversed.toList();

    final a = FrameTimeStats.of(ascending);
    final b = FrameTimeStats.of(shuffled);

    expect(a.p50, b.p50);
    expect(a.p90, b.p90);
    expect(a.p99, b.p99);
    expect(a.worst, b.worst);
  });

  test('a single outlier shows in worst but not necessarily in p99', () {
    // This is the whole reason worst exists as its own field, separate from
    // p99: a one-in-a-hundred stutter is real, but nearest-rank p99 over
    // exactly 100 samples looks at the 99th-smallest, not the 100th.
    final samples = [
      for (var i = 0; i < 99; i++) const Duration(milliseconds: 5),
      const Duration(milliseconds: 200),
    ];
    final stats = FrameTimeStats.of(samples);

    expect(stats.sampleCount, 100);
    expect(stats.p50, const Duration(milliseconds: 5));
    expect(stats.p99, const Duration(milliseconds: 5));
    expect(stats.worst, const Duration(milliseconds: 200));
  });

  test('a single sample is every percentile at once', () {
    final stats = FrameTimeStats.of(const [Duration(milliseconds: 7)]);

    expect(stats.p50, const Duration(milliseconds: 7));
    expect(stats.p90, const Duration(milliseconds: 7));
    expect(stats.p99, const Duration(milliseconds: 7));
    expect(stats.worst, const Duration(milliseconds: 7));
  });

  test('toJson reports milliseconds, not microseconds or Duration', () {
    final stats = FrameTimeStats.of(const [Duration(milliseconds: 8)]);
    final json = stats.toJson();

    expect(json['sampleCount'], 1);
    expect(json['p50Ms'], 8.0);
    expect(json['worstMs'], 8.0);
  });
}
