import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/glass_glow.dart';

void main() {
  test('none() glows nothing', () {
    expect(const GlassGlow.none().isActive, isFalse);
  });

  test('a zero-strength glow is inactive however large its radius', () {
    expect(
      const GlassGlow(
        centre: Offset(10, 10),
        radius: 200,
        strength: 0,
      ).isActive,
      isFalse,
    );
  });

  test('a zero-radius glow is inactive however strong', () {
    expect(
      const GlassGlow(centre: Offset(10, 10), radius: 0, strength: 1).isActive,
      isFalse,
    );
  });

  test('glows compare by value', () {
    expect(
      const GlassGlow(centre: Offset(1, 2), radius: 3, strength: 4),
      equals(const GlassGlow(centre: Offset(1, 2), radius: 3, strength: 4)),
    );
  });
}
