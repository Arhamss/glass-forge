import 'package:flutter/material.dart';
import 'package:glass_forge/glass_forge.dart';

void main() => runApp(const ExampleApp());

/// The smallest honest demonstration of `glass_forge`.
///
/// One glass surface you can drag, over a backdrop coarse enough to show the
/// refraction, with the three material presets a tap apart. Everything here
/// is package API; there are no helpers hiding the interesting parts.
class ExampleApp extends StatelessWidget {
  /// Creates the example.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'glass_forge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // Wrap the app once. The engine then resolves a tier from the GPU, the
      // device's thermal state, the frame rate it is actually achieving, and
      // the user's accessibility settings — and degrades the glass to match.
      // Without this, Reduce Transparency and Increase Contrast change
      // nothing at all.
      home: const GlassTierScope(child: ExampleScreen()),
    );
  }
}

/// The one screen.
class ExampleScreen extends StatefulWidget {
  /// Creates the screen.
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  static final _presets = <String, GlassMaterial>{
    // The lens: refraction across the whole surface, the look
    // `liquid_glass_renderer` gives.
    'Dome': GlassMaterial.dome(),
    // Apple's iOS 26 material, fitted against real captures: a thin bending
    // band at the rim, and an interior left undistorted.
    'Regular': GlassMaterial.regular(brightness: Brightness.dark),
    // Apple's clear variant — no adaptation, and a dark scrim over bright
    // backdrops instead.
    'Clear': GlassMaterial.clear(),
  };

  String _preset = 'Dome';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Whatever the glass refracts has to be painted *behind* the layer,
          // never inside it — a backdrop filter can only bend what was
          // already on screen beneath it.
          //
          // It also has to be coarser than the refraction. The glass displaces
          // the backdrop by tens of pixels; a pattern finer than that is
          // pushed through whole periods and lands looking exactly like
          // itself, so the glass appears to do nothing.
          const _Backdrop(),

          Center(
            child: GlassLayer(
              material: _presets[_preset]!,
              // Press it, drag it, throw it. The squash and stretch are
              // derived from the spring's own velocity rather than animated
              // separately, which is what keeps it looking like a liquid
              // rather than a rectangle being scaled.
              child: InteractiveGlass(
                drag: const GlassDrag(),
                settleMotion: const GlassMotion.bouncy(),
                child: const SizedBox(
                  width: 220,
                  height: 220,
                  child: Glass(
                    shape: GlassSuperellipse(
                      radius: BorderRadius.all(Radius.circular(56)),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _PresetBar(
                presets: _presets.keys.toList(),
                selected: _preset,
                onSelected: (name) => setState(() => _preset = name),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The preset switcher, painted rather than glass.
///
/// Deliberately solid. On a physical iPhone a glass surface drawn over
/// another glass surface reads a stale frame — including its own previous
/// output — and washes out to white within a few frames
/// ([flutter#187820](https://github.com/flutter/flutter/issues/187820)). The
/// simulator renders it correctly, so this is easy to ship by accident. The
/// rule that avoids it: at most one glass surface at any point on screen.
class _PresetBar extends StatelessWidget {
  const _PresetBar({
    required this.presets,
    required this.selected,
    required this.onSelected,
  });

  final List<String> presets;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xE6141820),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final name in presets)
            GestureDetector(
              onTap: () => onSelected(name),
              behavior: HitTestBehavior.opaque,
              child: Container(
                // An explicit height, not an alignment. A Container with an
                // alignment expands to fill whatever bounded space it is
                // given, which in a bar like this silently swallows the
                // screen.
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: name == selected
                      ? const Color(0x1FFFFFFF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    color: name == selected
                        ? Colors.white
                        : const Color(0x99FFFFFF),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Something with enough structure to see the glass bend.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF2B3A8F),
            Color(0xFFB1408A),
            Color(0xFFE8763C),
          ],
        ),
      ),
      child: CustomPaint(painter: _GridPainter(), child: SizedBox.expand()),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  /// Comfortably larger than the displacement the presets apply, so the bend
  /// reads as a bend rather than as an identical square a few cells over.
  static const _cell = 56.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x24FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var x = 0.0; x <= size.width; x += _cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += _cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
