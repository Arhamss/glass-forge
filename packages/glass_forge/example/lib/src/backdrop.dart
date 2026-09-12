import 'package:flutter/widgets.dart';
import 'package:glass_forge_example/src/theme.dart';

/// The photograph, and the only scrim in the app.
///
/// Everything here is painted *behind* the glass layer, which is the whole
/// reason it can be refracted: a backdrop filter bends what is already
/// beneath it and nothing else. Put the photograph inside the layer instead
/// and the glass has nothing to work with.
///
/// The scrim runs down from the top and stops before the middle. It is there
/// for the painted title, which sits on bare photograph and would otherwise
/// have to survive a sunlit ridge; the chrome at the bottom of the frame gets
/// no scrim at all, because making it readable is the glass's job and a scrim
/// under it would quietly do that job instead.
class Backdrop extends StatelessWidget {
  const Backdrop({required this.photo, super.key});

  final String photo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: sceneDuration(context, const Duration(milliseconds: 420)),
          // Expanded explicitly. `AnimatedSwitcher` lays its child out in a
          // loose Stack, so a bare `Image` takes its own aspect ratio and
          // letterboxes itself against a taller screen — `BoxFit.cover` can
          // only fill the box it is given.
          child: SizedBox.expand(
            key: ValueKey(photo),
            child: Image.asset(photo, fit: BoxFit.cover),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.28, 0.52],
              colors: [
                Color(0xC7000000),
                Color(0x8A000000),
                Color(0x00000000),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
