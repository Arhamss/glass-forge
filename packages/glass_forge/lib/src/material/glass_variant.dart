/// The two materials Apple ships, and the only two worth having.
///
/// Apple is explicit that these "should never be mixed": regular adapts to
/// what is behind it, clear does not and takes a dimming layer instead.
enum GlassVariant {
  /// Adapts luminosity and tint to stay legible over anything.
  regular,

  /// Permanently more transparent, with no adaptive behaviour.
  ///
  /// Only correct over media-rich content, where a dimming layer will not
  /// hurt the content and the foreground is bold and bright.
  clear,
}
