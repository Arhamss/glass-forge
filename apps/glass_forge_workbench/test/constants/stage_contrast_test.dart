import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/constants/app_colors.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color color) {
  double channel(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

/// [foreground] composited over [background] at [alpha].
Color _over(Color foreground, Color background, double alpha) {
  return Color.from(
    alpha: 1,
    red: foreground.r * alpha + background.r * (1 - alpha),
    green: foreground.g * alpha + background.g * (1 - alpha),
    blue: foreground.b * alpha + background.b * (1 - alpha),
  );
}

void main() {
  // The one selection fill the workbench uses, on every rail, segmented
  // control, roster row and tier rung.
  final selectedRow = _over(
    AppColors.stageForeground,
    AppColors.stageRaised,
    0.12,
  );

  group('stage text clears 4.5:1 where it is actually drawn', () {
    test('on the instrument sheet', () {
      expect(
        _contrast(AppColors.stageForeground, AppColors.stageRaised),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.stageForegroundMuted, AppColors.stageRaised),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.stageForegroundSubtle, AppColors.stageRaised),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('on the stage ground', () {
      expect(
        _contrast(AppColors.stageForegroundMuted, AppColors.stageGround),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('on a selected row, where the fill lifts the ground', () {
      // The reason the roster rows and tier rungs step their secondary
      // line up to the muted grey when selected: the subtle one lands at
      // 3.3:1 here, which reads fine and fails.
      expect(
        _contrast(AppColors.stageForegroundSubtle, selectedRow),
        lessThan(4.5),
      );
      expect(
        _contrast(AppColors.stageForegroundMuted, selectedRow),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.stageForeground, selectedRow),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the accent clears 3:1, which is all a state marker needs', () {
      // The green is never body text. It marks a pinned tier and nothing
      // else, so the non-text contrast floor is the one that applies.
      expect(
        _contrast(AppColors.stageAccent, AppColors.stageRaised),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(AppColors.stageAccent, selectedRow),
        greaterThanOrEqualTo(3),
      );
    });
  });
}
