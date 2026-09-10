import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/scene/blend_group_link.dart';

void main() {
  test('a group start encodes negative and round-trips its blend', () {
    final marker = encodeBlendMarker(startsGroup: true, blend: 20);
    expect(marker, lessThan(0));

    final decoded = decodeBlendMarker(marker);
    expect(decoded.startsGroup, isTrue);
    expect(decoded.blend, closeTo(20, 1e-9));
  });

  test('a continuation encodes non-negative and round-trips its blend', () {
    final marker = encodeBlendMarker(startsGroup: false, blend: 20);
    expect(marker, greaterThanOrEqualTo(0));

    final decoded = decodeBlendMarker(marker);
    expect(decoded.startsGroup, isFalse);
    expect(decoded.blend, closeTo(20, 1e-9));
  });

  test('a zero-blend group start is still distinguishable from a member', () {
    // The -(blend + 1) offset exists for exactly this: without it a group
    // start with blend 0 would encode as -0.0, which compares equal to 0.0
    // and would be read as a continuation.
    final start = encodeBlendMarker(startsGroup: true, blend: 0);
    expect(start, lessThan(0));
    expect(decodeBlendMarker(start).startsGroup, isTrue);
  });

  test('tracks membership and reports the first member', () {
    final link = BlendGroupLink(blend: 12)..add('a')..add('b');
    expect(link.isFirst('a'), isTrue);
    expect(link.isFirst('b'), isFalse);

    link.remove('a');
    expect(link.isFirst('b'), isTrue);

    link.remove('b');
    expect(link.isEmpty, isTrue);
  });
}
