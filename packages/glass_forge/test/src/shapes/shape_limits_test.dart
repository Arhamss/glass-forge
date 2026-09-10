import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

void main() {
  test('the shape cap fits the uniform budget it claims', () {
    // Three vec4 per shape, four floats each.
    const floatsPerShape = 3 * 4;
    expect(kMaxShapes * floatsPerShape, lessThanOrEqualTo(kMaxShapeFloats));
  });

  test(
    'the provenance states the cap is derived, not device-confirmed, and '
    'names what would confirm it',
    () {
      expect(kMaxShapesProvenance, contains('Derived'));
      expect(kMaxShapesProvenance, contains('shaders/probe.frag'));
    },
  );
}
