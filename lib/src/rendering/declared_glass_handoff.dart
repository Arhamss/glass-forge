/// Marks a presence animation whose glass is declared to sit over one
/// other glass on purpose. Internal to this package; not exported.
///
/// `RenderGlassLayer` warns when shapes in two different backdrop passes
/// overlap, because two passes over the same pixels is flutter#187820.
/// This package's own `GlassTabBar` overlaps on purpose: its selection is
/// a glass lens over the bar's glass, always, at rest too. A shape whose
/// `GlassPresence` animation implements this interface is left out of that
/// warning, so the package's own widgets do not teach every debug app to
/// ignore it. The exemption silences a diagnostic; it does not make the
/// overlap safe on a physical iPhone, which still has to be checked there.
///
/// The exemption is for one pair, not for everything nearby: only an
/// overlap with glass whose presence is [handsOffWith] is left out. The
/// same lens swelling over some other glass in the layer — a floating
/// button next to the bar — is a real overlap, and still warns.
///
/// Implement it only for an overlap a widget of this package makes by
/// design, and say in that widget's documentation that it does.
abstract interface class DeclaredGlassHandoff {
  /// The presence, by identity, of the glass this one hands off over: the
  /// tab bar's own presence for its lens. Null for glass with no presence
  /// of its own.
  Object? get handsOffWith;
}
