import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/benchmark/benchmark_run_mode.dart';

void main() {
  test('only debug is untrustworthy', () {
    expect(BenchmarkRunMode.debug.isTrustworthy, isFalse);
    expect(BenchmarkRunMode.profile.isTrustworthy, isTrue);
    expect(BenchmarkRunMode.release.isTrustworthy, isTrue);
  });

  test('only debug carries a warning banner', () {
    expect(BenchmarkRunMode.debug.warningBanner, isNotEmpty);
    expect(BenchmarkRunMode.profile.warningBanner, isEmpty);
    expect(BenchmarkRunMode.release.warningBanner, isEmpty);
  });

  test('the debug warning names the fix, not just the problem', () {
    // A banner that just says "untrustworthy" without saying what to do
    // about it gets ignored the same way a bare warning symbol does.
    expect(BenchmarkRunMode.debug.warningBanner, contains('--profile'));
  });

  test('current() reports debug under flutter test', () {
    // flutter_test always runs the JIT with assertions on -- there is no
    // way to force kProfileMode/kReleaseMode from inside a test, so this is
    // the one BenchmarkRunMode.current() result this suite can pin. The
    // per-mode behaviour above is what actually needs coverage; this test
    // only confirms current() reads the real constant rather than being
    // hard-coded to return something else.
    expect(BenchmarkRunMode.current(), BenchmarkRunMode.debug);
  });
}
