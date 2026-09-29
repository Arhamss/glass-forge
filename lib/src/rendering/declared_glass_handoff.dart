/// Marks a presence animation whose glass is a declared, bounded handoff
/// over other glass. Internal to this package; not exported.
///
/// `RenderGlassLayer` warns when shapes in two different backdrop passes
/// overlap, because two passes over the same pixels is flutter#187820. A
/// few of this package's own widgets overlap on purpose, for a bounded
/// time, as a handoff: `GlassTabBar`'s lens rises over the bar only while
/// the selection is travelling and is gone once it lands. A shape whose
/// `GlassPresence` animation implements this interface is left out of that
/// warning, so the package's own widgets do not teach every debug app to
/// ignore it.
///
/// The exemption is for one pair, not for everything nearby: only an
/// overlap with glass whose presence is [handsOffWith] is left out. The
/// same lens swelling over some other glass in the layer — a floating
/// button next to the bar — is a real overlap, and still warns.
///
/// The bound is the implementer's promise, not something the layer checks.
/// Only implement it for glass that provably reaches presence 0 on its own
/// within a short, stated time.
abstract interface class DeclaredGlassHandoff {
  /// The presence, by identity, of the glass this one hands off over: the
  /// tab bar's own presence for its lens. Null for glass with no presence
  /// of its own.
  Object? get handsOffWith;
}
