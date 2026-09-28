import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The app's icons: Iconsax, as SVG assets under `assets/icons/`.
///
/// Linear for anything that labels a control, bold for media transport and
/// confirmations, which Apple draws filled too.
abstract final class Glyphs {
  static const String lens = 'assets/icons/mask.svg';
  static const String liquid = 'assets/icons/drop.svg';
  static const String kit = 'assets/icons/category.svg';
  static const String photo = 'assets/icons/gallery.svg';
  static const String wifi = 'assets/icons/wifi.svg';
  static const String bluetooth = 'assets/icons/bluetooth.svg';
  static const String moon = 'assets/icons/moon.svg';
  static const String contrast = 'assets/icons/contrast.svg';
  static const String rotate = 'assets/icons/rotate_right.svg';
  static const String sun = 'assets/icons/sun.svg';
  static const String sunBold = 'assets/icons/sun_bold.svg';
  static const String volumeLow = 'assets/icons/volume_low.svg';
  static const String volumeHigh = 'assets/icons/volume_high.svg';
  static const String previous = 'assets/icons/previous.svg';
  static const String play = 'assets/icons/play.svg';
  static const String pause = 'assets/icons/pause.svg';
  static const String next = 'assets/icons/next.svg';
  static const String reset = 'assets/icons/refresh.svg';
  static const String code = 'assets/icons/code.svg';
  static const String done = 'assets/icons/tick_circle.svg';
}

/// An Iconsax glyph, tinted like an [Icon]: [color], or the ambient
/// [IconTheme]'s.
class Glyph extends StatelessWidget {
  const Glyph(this.asset, {this.size = 24, this.color, super.key});

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint =
        color ?? IconTheme.of(context).color ?? const Color(0xFFFFFFFF);
    // Centred the way `Icon` is: handed tight constraints — the whole face
    // of a `Glass`, say, or a fixed-size `Container` — a bare SVG would
    // stretch to fill them and ignore [size].
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      ),
    );
  }
}
