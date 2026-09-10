import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

void main() {
  test('the shape cap fits the uniform budget it claims', () {
    // Three vec4 per shape, four floats each.
    const floatsPerShape = 3 * 4;
    expect(kMaxShapes * floatsPerShape, lessThanOrEqualTo(kMaxShapeFloats));
  });

  test('the cap is documented as measured, not assumed', () {
    expect(kMaxShapesProvenance, isNotEmpty);
  });
}
