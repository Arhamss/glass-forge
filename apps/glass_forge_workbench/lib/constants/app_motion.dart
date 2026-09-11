import 'package:flutter/animation.dart';

/// Durations and curves for everything that is not a glass spring. Springs
/// come from glass_forge's `GlassMotion`.
abstract class AppMotion {
  static const press = Duration(milliseconds: 120);
  static const select = Duration(milliseconds: 220);
  static const sheet = Duration(milliseconds: 360);
  static const fadeThrough = Duration(milliseconds: 180);
  static const stagger = Duration(milliseconds: 40);
  static const presetTween = Duration(milliseconds: 280);
  static const glassSwap = Duration(milliseconds: 120);

  static const selectCurve = Curves.easeOutCubic;
  static const pressCurve = Curves.easeOut;
}
