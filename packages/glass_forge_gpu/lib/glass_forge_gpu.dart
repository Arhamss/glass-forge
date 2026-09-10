/// Flutter GPU geometry producer for `glass_forge`.
///
/// `glass_forge` renders its glass by first baking shape geometry — surface
/// normal, edge distance and displacement magnitude — into a matte texture,
/// then sampling that matte in a single backdrop pass. Producing the matte is
/// the expensive half, and there is more than one way to do it.
///
/// The core package ships a producer built on runtime-effect shaders, which
/// works on every backend Flutter supports. This package adds a second one
/// built on Flutter GPU: it renders into a `devicePrivate` texture directly,
/// skipping the `toImageSync` round-trip and the display-list retention that
/// comes with it.
///
/// It lives in its own package because it is not free to depend on. Flutter
/// GPU is a beta SDK dependency, and compiling its shader bundle needs a
/// native-assets build hook. Consumers who add this package opt into both;
/// consumers who do not are unaffected and never compile either.
///
/// Selection is a tier decision made at runtime, not a compile-time constant —
/// a device under thermal pressure can fall back to the runtime producer, or
/// to no matte at all, without the widget tree noticing.
///
/// Nothing is implemented yet. See
/// `docs/superpowers/specs/2026-09-10-renderer-core-design.md` §4 for the
/// producer interface this package will implement.
library;
