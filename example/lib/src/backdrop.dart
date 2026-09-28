import 'package:flutter/widgets.dart';
import 'package:glass_forge_example/src/ui.dart';

/// The photograph behind everything, drifting slowly.
///
/// It is painted *behind* the `GlassLayer`, not inside it: a backdrop
/// filter can only bend what is already beneath it. The drift is there so
/// there is always something moving under the glass — refraction over a
/// still image is a picture of refraction.
class Backdrop extends StatefulWidget {
  const Backdrop({required this.photo, super.key});

  final String photo;

  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _drift,
          builder: (context, child) {
            final t = Curves.easeInOutSine.transform(_drift.value);
            return Transform.scale(
              scale: 1.12 - 0.06 * t,
              alignment: Alignment(-0.6 + 1.2 * t, -0.2 + 0.3 * t),
              child: child,
            );
          },
          child: AnimatedSwitcher(
            duration: motion(context, const Duration(milliseconds: 700)),
            switchInCurve: Curves.easeOut,
            // Sized explicitly: AnimatedSwitcher lays its child out loose,
            // and a bare Image would letterbox itself.
            child: SizedBox.expand(
              key: ValueKey(widget.photo),
              child: Image.asset(widget.photo, fit: BoxFit.cover),
            ),
          ),
        ),
        // A top scrim for the title, which sits on bare photograph. None at
        // the bottom: keeping the chrome down there readable is the glass's
        // job.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.3],
              colors: [Color(0x99000000), Color(0x00000000)],
            ),
          ),
        ),
      ],
    );
  }
}
