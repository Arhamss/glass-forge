import 'package:flutter/foundation.dart';

/// Encodes group membership into a single float the shader can branch on.
///
/// The shader walks the shape array once and needs to know, per shape, whether
/// it opens a new blend group and how wide that group's smooth-min is. Packing
/// both into one float keeps the per-shape uniform stride at three `vec4`.
///
/// Negative means "starts a group", carrying `-(blend + 1)`. The `+ 1` matters:
/// without it, a group opening with a blend of zero would encode as `-0.0`,
/// which compares equal to `0.0` and would be read as a continuation.
double encodeBlendMarker({required bool startsGroup, required double blend}) {
  return startsGroup ? -(blend + 1) : blend;
}

/// Reads a marker produced by [encodeBlendMarker].
({bool startsGroup, double blend}) decodeBlendMarker(double marker) {
  if (marker < 0) {
    return (startsGroup: true, blend: -marker - 1);
  }
  return (startsGroup: false, blend: marker);
}

/// Membership of one blend group.
///
/// Scoped to its own layer. A nested layer's shapes must never register into
/// an outer layer's group, or they would blend across a boundary the user
/// drew deliberately.
///
/// A [ChangeNotifier] on purpose: which member is "first" — and therefore
/// carries the group-opening marker — can change without that member's own
/// widget rebuilding at all. If the first member unmounts, the new first
/// member needs to hear about it and re-sync its own geometry; nothing about
/// *its* build changed, only the group's. Listening is how it finds out.
class BlendGroupLink extends ChangeNotifier {
  /// Creates a group whose members merge over [blend] logical pixels.
  BlendGroupLink({required this._blend});

  double _blend;

  /// How wide the smooth-min between members is, in logical pixels.
  ///
  /// Mutable, not replaced: swapping in a whole new [BlendGroupLink] when
  /// this changes would force every still-attached member to migrate
  /// listeners across two objects for no reason, and would leave the old
  /// link's disposal timing to chase whichever member unsubscribes last.
  double get blend => _blend;
  set blend(double value) {
    if (_blend == value) {
      return;
    }
    _blend = value;
    notifyListeners();
  }

  final List<Object> _members = <Object>[];

  /// Whether the group has no members left.
  bool get isEmpty => _members.isEmpty;

  /// The members, in insertion order.
  ///
  /// Order is load-bearing: the quadratic smooth-min is **not associative**,
  /// so folding the same shapes in a different order gives a different
  /// surface. Insertion order makes it deterministic.
  List<Object> get members => List<Object>.unmodifiable(_members);

  /// Adds [key] to the group if it is not already a member.
  void add(Object key) {
    if (_members.contains(key)) {
      return;
    }
    _members.add(key);
    notifyListeners();
  }

  /// Removes [key] from the group.
  void remove(Object key) {
    if (!_members.remove(key)) {
      return;
    }
    notifyListeners();
  }

  /// Whether [key] is the group's first member, and therefore the shape that
  /// carries the group-opening marker.
  bool isFirst(Object key) => _members.isNotEmpty && _members.first == key;
}
