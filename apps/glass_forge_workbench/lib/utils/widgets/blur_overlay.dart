import 'dart:ui';

import 'package:glass_forge_workbench/exports.dart';

class CustomBlurOverlay extends StatelessWidget {
  const CustomBlurOverlay({
    required this.onDismiss,
    super.key,
    this.blurStrength = 6.3,
    this.scrimOpacity = 0.01,
    this.scrimColor = const Color(0xFF40475B),
  });

  final VoidCallback onDismiss;
  final double blurStrength;
  final double scrimOpacity;
  final Color scrimColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onDismiss,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurStrength,
              sigmaY: blurStrength,
            ),
            child: SizedBox.expand(
              child: Container(
                color: scrimColor.withValues(alpha: scrimOpacity),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
