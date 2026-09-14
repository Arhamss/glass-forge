import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/backdrop.dart';
import 'package:glass_forge_example/src/chrome.dart';
import 'package:glass_forge_example/src/scene.dart';
import 'package:glass_forge_example/src/scenes/blend_scene.dart';
import 'package:glass_forge_example/src/scenes/edge_scene.dart';
import 'package:glass_forge_example/src/scenes/motion_scene.dart';
import 'package:glass_forge_example/src/scenes/system_scene.dart';
import 'package:glass_forge_example/src/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Geist', 'Geist Mono'],
      await rootBundle.loadString('assets/licenses/geist_ofl.txt'),
    );
  });
  runApp(const GlassForgeExample());
}

/// Five scenes over five photographs.
///
/// Everything on screen is this package's own API. There is no wrapper layer
/// between the reader and `GlassLayer`, `Glass`, `GlassMaterial`,
/// `InteractiveGlass` and `GlassSurface` — where the example needs a widget
/// of its own, it is a painted control, and it says so.
class GlassForgeExample extends StatefulWidget {
  const GlassForgeExample({super.key});

  @override
  State<GlassForgeExample> createState() => _GlassForgeExampleState();
}

class _GlassForgeExampleState extends State<GlassForgeExample> {
  /// The tier the System scene pins, or null to let the engine decide.
  ///
  /// Lifted to the root because the scope that reads it has to sit above
  /// every layer in the app: one engine, one frame-timings callback, one pair
  /// of platform channels, however many screens adopt the answer.
  final _requested = ValueNotifier<GlassTier?>(null);

  @override
  void dispose() {
    _requested.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GlassTier?>(
      valueListenable: _requested,
      builder: (context, requested, _) {
        // Wrap the app once. The engine resolves a tier from four inputs —
        // what the GPU can do, how hot the device is, what frame rate it is
        // actually achieving, and the user's accessibility settings — and
        // every layer below degrades to match. Without this, Reduce
        // Transparency and Increase Contrast change nothing at all.
        return GlassTierScope(
          requested: requested,
          // The design system, with two numbers moved. Naming one field of
          // one scale leaves every other token at its default, which is the
          // point of having them: the app is saying "my panels are less round
          // than yours", not restating a theme.
          child: GlassTheme(
            data: const GlassThemeData(
              brightness: Brightness.dark,
              tokens: GlassTokens(
                radius: GlassRadiusScale(large: 26, extraLarge: 30),
              ),
            ),
            child: MaterialApp(
              title: 'glass_forge',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                brightness: Brightness.dark,
                fontFamily: 'Geist',
                scaffoldBackgroundColor: Tone.ground,
              ),
              home: Stage(requested: _requested),
            ),
          ),
        );
      },
    );
  }
}

/// The one screen: a photograph, one glass layer over it, and a scene.
///
/// **One layer for the whole screen.** A `GlassLayer` captures the backdrop
/// once per distinct material among its shapes, so five surfaces under one
/// layer cost at most five captures however many widgets play them, where a
/// layer per surface costs one each.
///
/// **At most one glass surface at any point on screen.** On a physical iPhone
/// a glass surface drawn over another reads a stale frame — including its own
/// previous output — and washes out white within a few frames
/// (flutter#187820). The simulator renders it correctly, so it is easy to
/// ship by accident. Nothing here overlaps: the specimen sits above the
/// control panel, the panel above the tab bar, and every control drawn *on* a
/// glass surface is paint rather than more glass.
class Stage extends StatefulWidget {
  const Stage({required this.requested, super.key});

  final ValueNotifier<GlassTier?> requested;

  @override
  State<Stage> createState() => _StageState();
}

class _StageState extends State<Stage> {
  int _index = 0;
  bool _dimmed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final scene in scenes) {
      unawaited(precacheImage(AssetImage(scene.photo), context));
    }
  }

  /// The scene at [index], keyed to the order of `scenes`.
  Widget _sceneFor(int index, SceneInfo info) => switch (index) {
    1 => EdgeScene(info: info),
    2 => BlendScene(info: info),
    3 => MotionScene(info: info),
    4 => SystemScene(
      info: info,
      requested: widget.requested,
      onDim: () => setState(() => _dimmed = true),
    ),
    _ => LensScene(info: info),
  };

  @override
  Widget build(BuildContext context) {
    final scene = scenes[_index];
    final padding = MediaQuery.paddingOf(context);

    // A Scaffold, for one reason: `MaterialApp` marks any text that is not
    // inside a `Material` with a debug underline, and every label in this app
    // is drawn straight onto glass. Its background is the ground colour, seen
    // only in the frame before the first photograph decodes.
    return Scaffold(
      backgroundColor: Tone.ground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Behind the layer, never inside it. A backdrop filter can only
          // bend what is already painted beneath it, so a photograph placed
          // inside the layer would be refracted by nothing at all.
          Backdrop(photo: scene.photo),

          GlassLayer(
            material: scene.material,
            // The scrim replaces the screen rather than covering it, and it
            // does so in one frame with no cross-fade. Both are the same
            // rule: for the moment a full-screen surface is up it has to be
            // the only glass on screen, and a fade would stack the two for
            // the length of the fade.
            child: _dimmed
                ? ScrimOverlay(
                    onDismiss: () => setState(() => _dimmed = false),
                  )
                : Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      // Anything pinned to the top of an edge-to-edge surface
                      // needs its own inset, or it prints through the clock.
                      padding.top + 10,
                      20,
                      padding.bottom + 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(scene: scene),
                        const SizedBox(height: 18),
                        Expanded(child: _sceneFor(_index, scene)),
                        const SizedBox(height: 10),
                        _SceneTabs(
                          index: _index,
                          backdrop: scene.barBackdrop,
                          onChanged: (i) => setState(() => _index = i),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.scene});

  final SceneInfo scene;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: sceneDuration(context, const Duration(milliseconds: 320)),
      child: Column(
        key: ValueKey(scene.name),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'glass_forge',
            style: context.mono.copyWith(color: context.inkTertiary),
          ),
          const SizedBox(height: 6),
          Text(scene.name, style: context.display),
          const SizedBox(height: 6),
          Text(
            scene.blurb,
            style: context.body.copyWith(color: context.inkSecondary),
          ),
        ],
      ),
    );
  }
}

/// The scene switcher: a navigation bar, and the thinnest glass on screen.
///
/// At 52 logical pixels the short side is under the size gate, so this is one
/// of the surfaces that gets to *flip* its whole scheme against what is
/// behind it rather than merely thickening its tint. Apple's rule is about
/// thinness, not area — the backdrop under a bar is one strip of one thing,
/// so one luminance reading describes all of it.
class _SceneTabs extends StatelessWidget {
  const _SceneTabs({
    required this.index,
    required this.backdrop,
    required this.onChanged,
  });

  final int index;
  final Color backdrop;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: GlassSurface.navigationBar(
        backdrop: backdrop,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: SegmentedControl<int>(
            options: List<int>.generate(scenes.length, (i) => i),
            selected: index,
            onChanged: onChanged,
            labelOf: (i) => scenes[i].name,
          ),
        ),
      ),
    );
  }
}

/// The headline: one dome of glass, over a ridge coarse enough to bend.
///
/// `GlassMaterial.dome()` treats the shape as a sphere cap over its whole
/// interior, so everything behind it is displaced — the middle magnifies and
/// the rim compresses. Apple's material, which the Edge scene shows, refracts
/// only inside a band at the rim and leaves the interior flat. They are two
/// different physical models, not two settings of one.
class LensScene extends StatefulWidget {
  const LensScene({required this.info, super.key});

  final SceneInfo info;

  @override
  State<LensScene> createState() => _LensSceneState();
}

class _LensSceneState extends State<LensScene> {
  GlassShape _shape = const GlassSuperellipse(
    radius: BorderRadius.all(Radius.circular(72)),
  );
  double _refraction = 40;

  static const _shapes = <String, GlassShape>{
    'Squircle': GlassSuperellipse(
      radius: BorderRadius.all(Radius.circular(72)),
    ),
    'Circle': GlassOval(),
    'Rounded': GlassRoundedRectangle(
      radius: BorderRadius.all(Radius.circular(28)),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return SceneShell(
      backdrop: widget.info.panelBackdrop,
      specimen: SizedBox.square(
        dimension: 260,
        // Press it, drag it, throw it. The squash and stretch are read
        // straight off the spring's velocity rather than animated as a
        // channel of their own, which is what keeps the deformation caused by
        // the motion instead of merely correlated with it.
        child: InteractiveGlass(
          drag: const GlassDrag(
            // The rubber band is what keeps this composition legal. It
            // asymptotes at 72 logical pixels and never reaches it, so the
            // specimen cannot be dragged onto the control panel below — no
            // gesture, however long, puts glass over glass.
            overdrag: GlassOverdrag(limit: 72),
          ),
          child: Glass(
            shape: _shape,
            material: GlassMaterial.dome().copyWith(
              edgeRefraction: _refraction,
            ),
          ),
        ),
      ),
      controls: SegmentedControl<String>(
        options: _shapes.keys.toList(),
        selected: _shapes.entries.firstWhere((e) => e.value == _shape).key,
        onChanged: (name) => setState(() => _shape = _shapes[name]!),
        labelOf: (name) => name,
      ),
      extraControls: ValueSlider(
        label: 'Refraction',
        value: _refraction,
        min: 0,
        max: 64,
        format: (v) => '${v.round()} px',
        onChanged: (v) => setState(() => _refraction = v),
      ),
      code: 'GlassMaterial.dome()'
          '.copyWith(edgeRefraction: ${_refraction.round()})',
    );
  }
}
