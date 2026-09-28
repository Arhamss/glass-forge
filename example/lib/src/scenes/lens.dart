import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/ui.dart';

/// One big piece of glass: drag it, fling it, tap it to change its shape.
///
/// Empty on purpose. Anything drawn on top of the glass competes with the
/// refraction for attention, and the refraction is the thing to look at.
class LensScene extends StatefulWidget {
  const LensScene({super.key});

  @override
  State<LensScene> createState() => _LensSceneState();
}

class _Form {
  const _Form(this.size, this.radius, {this.superellipse = false});

  final Size size;
  final double radius;
  final bool superellipse;
}

class _LensSceneState extends State<LensScene> {
  static const List<_Form> _forms = [
    _Form(Size(200, 200), 100),
    _Form(Size(210, 210), 64, superellipse: true),
    _Form(Size(300, 116), 58),
    _Form(Size(150, 240), 40, superellipse: true),
  ];

  int _form = 0;

  @override
  Widget build(BuildContext context) {
    final form = _forms[_form];
    return SizedBox(
      width: 320,
      height: 320,
      child: Center(
        child: Arrive(
          scale: 0.2,
          child: InteractiveGlass(
            // Picked up and carried: it tracks the finger one to one, with
            // no rubber band to make it lag, and floats home on release. A
            // rubber band is for dragging *past* a limit, and a lens you
            // are moving about has none.
            drag: const GlassDrag(overdrag: GlassOverdrag.none()),
            // The default press-stretch is sized for a 44 pt button. On a
            // 200 pt lens the same fraction is a 100 pt lean.
            pressStretch: const GlassPressStretch(intensity: 0.08),
            onTap: () => setState(() => _form = (_form + 1) % _forms.length),
            // The morph between forms is a plain tween of size and radius.
            // The shape is re-registered every paint, so the refraction
            // follows the outline frame by frame with nothing special done.
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: form.radius),
              duration: motion(context, const Duration(milliseconds: 650)),
              curve: Curves.elasticOut,
              builder: (context, radius, _) {
                final corners = BorderRadius.circular(radius.clamp(0, 999));
                return AnimatedContainer(
                  duration: motion(context, const Duration(milliseconds: 650)),
                  curve: Curves.elasticOut,
                  width: form.size.width,
                  height: form.size.height,
                  child: Glass(
                    shape: form.superellipse
                        ? GlassSuperellipse(radius: corners)
                        : GlassRoundedRectangle(radius: corners),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
