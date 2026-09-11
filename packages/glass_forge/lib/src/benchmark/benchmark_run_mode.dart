import 'package:flutter/foundation.dart';

/// Which Dart/Flutter compilation mode a benchmark ran under.
///
/// The three modes are not equally trustworthy. [debug] runs the JIT with
/// assertions and every framework debug check switched on -- often several
/// times slower than what a real device shows a user, so a number captured
/// in it is not a performance claim, it is a debug-mode number. [profile]
/// keeps tracing on while running compiled, optimised code, which is why it
/// is the mode this harness expects to run in. [release] is what ships, but
/// strips the very tracing this harness reads, so a report from it exists
/// only to confirm the app still builds and runs release, not to gate a
/// budget against.
enum BenchmarkRunMode {
  /// JIT, assertions on, framework debug checks on. Never a performance
  /// claim.
  debug,

  /// Compiled, optimised, tracing left on. What this harness is meant to
  /// measure in.
  profile,

  /// Fully compiled, tracing stripped. Numbers observed here did not come
  /// from this harness's own instrumentation.
  release;

  /// The mode this process is actually running in right now.
  static BenchmarkRunMode current() {
    if (kDebugMode) {
      return BenchmarkRunMode.debug;
    }
    if (kProfileMode) {
      return BenchmarkRunMode.profile;
    }
    return BenchmarkRunMode.release;
  }

  /// Whether a number captured in this mode may be presented as a
  /// performance claim.
  ///
  /// Only [debug] answers false. [release] is trustworthy for magnitude even
  /// though this harness cannot itself observe timings there -- a caller
  /// that got a [release]-mode report from elsewhere may still gate on it.
  bool get isTrustworthy => this != BenchmarkRunMode.debug;

  /// A loud, single-line warning for a report captured in [debug] mode.
  ///
  /// Empty for the other two modes -- callers should test [isTrustworthy]
  /// rather than this string being non-empty, but an empty string is still
  /// the correct thing to print when nothing needs saying.
  String get warningBanner {
    if (isTrustworthy) {
      return '';
    }
    return '*** DEBUG BUILD -- these numbers are not a performance claim. '
        'JIT, assertions and framework debug checks are all on. Re-run with '
        '`flutter run --profile` (or `--release`) before citing them '
        'anywhere. ***';
  }
}
