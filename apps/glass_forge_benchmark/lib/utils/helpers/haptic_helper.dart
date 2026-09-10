import 'package:flutter/services.dart';

class AppHaptics {
  AppHaptics._();

  static void success() => HapticFeedback.mediumImpact();

  static void error() => HapticFeedback.heavyImpact();

  static void tap() => HapticFeedback.lightImpact();

  static void toggle() => HapticFeedback.selectionClick();

  static void destructive() => HapticFeedback.heavyImpact();
}
