import 'package:glass_forge_workbench/exports.dart';

/// Proves the specular rim doesn't glow on a surface with nothing to
/// reflect.
///
/// Glass renderers commonly fake a rim highlight with a fixed-brightness
/// specular pass. Over a genuinely black backdrop that fake has nowhere to
/// hide — any renderer that doesn't grade the rim against the backdrop's
/// actual luminance will flicker a visible highlight over pure black. This
/// is the rim-flicker case behind upstream issue #112.
class VoidBackdrop extends StatelessWidget {
  /// Creates the backdrop.
  const VoidBackdrop({super.key});

  // Intentionally literal black, not AppColors.stageGround — the test is
  // specifically about a surface with zero luminance, which the app's dark
  // "ground" token (#0A0E17) is not.
  static const _pureBlack = Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: _pureBlack);
  }
}
