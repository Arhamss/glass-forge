/// A monotonically increasing change counter.
///
/// Comparing an integer is roughly two orders of magnitude cheaper than a deep
/// comparison of shape lists — upstream measured 735.8 ns against 5.7 ns — and
/// this sits on the paint path, so it runs every frame.
class SceneRevision {
  int _value = 0;

  /// The current revision.
  int get value => _value;

  /// Marks the scene changed.
  void bump() => _value++;
}
