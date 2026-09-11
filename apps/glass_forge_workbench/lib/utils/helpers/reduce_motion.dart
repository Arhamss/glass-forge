import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';

extension ReduceMotionX on BuildContext {
  /// Whether animation should be skipped.
  ///
  /// Both signals, because neither is enough alone: `disableAnimations` is
  /// the one tests and Android set, but iOS Reduce Motion never sets it
  /// (flutter#65874), which glass_forge reads from the engine instead.
  bool get reduceMotion =>
      MediaQuery.disableAnimationsOf(this) || GlassReduceMotion.instance.value;
}
