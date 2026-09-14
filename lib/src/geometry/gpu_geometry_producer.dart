/// The Flutter GPU-backed geometry producer, or a web-safe stand-in.
///
/// `package:flutter_gpu`'s `external` members are not valid for dart2js —
/// `flutter build web` fails outright ("Only JS interop members may be
/// 'external'") the moment anything transitively imports that package. That
/// had never been exercised before Task 19's sampling probe became the
/// first `GlassLayer` consumer in either app; see
/// `docs/reference/backdrop_sampling.md` for how it was found.
///
/// `dart.library.io`, not `dart.library.js_interop`, is *not* the condition
/// here on purpose: `dart analyze` resolves an unconditioned default branch
/// for static analysis regardless of platform, so the default has to be the
/// real implementation — matching what every native target (and this
/// package's own test suite, which asserts against its real constructor
/// signature) actually gets — with the web stub picked out specifically via
/// `dart.library.js_interop`, which only a JS/web compile target satisfies.
library;

export 'gpu_geometry_producer_io.dart'
    if (dart.library.js_interop) 'gpu_geometry_producer_stub.dart';
