import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/constants/app_colors.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final first = _luminance(a);
  final second = _luminance(b);
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  const grounds = <String, Color>{
    'ground': AppColors.ground,
    'surface': AppColors.surface,
    'surfaceRaised': AppColors.surfaceRaised,
  };

  for (final entry in grounds.entries) {
    test('primary text on ${entry.key} clears AA', () {
      expect(
        _contrast(AppColors.textPrimary, entry.value),
        greaterThanOrEqualTo(4.5),
      );
    });
    test('secondary text on ${entry.key} clears AA', () {
      expect(
        _contrast(AppColors.textSecondary, entry.value),
        greaterThanOrEqualTo(4.5),
      );
    });
    test('tertiary text on ${entry.key} clears AA', () {
      expect(
        _contrast(AppColors.textTertiary, entry.value),
        greaterThanOrEqualTo(4.5),
      );
    });
    test('the accent on ${entry.key} clears the 3:1 non-text floor', () {
      expect(_contrast(AppColors.accent, entry.value), greaterThanOrEqualTo(3));
    });
  }

  test('text on the accent clears AA', () {
    expect(
      _contrast(AppColors.onAccent, AppColors.accent),
      greaterThanOrEqualTo(4.5),
    );
  });
}
