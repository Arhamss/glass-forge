import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/home.dart';
import 'package:glass_forge_example/src/playground.dart';
import 'package:glass_forge_example/src/ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Geist', 'Geist Mono'],
      await rootBundle.loadString('assets/licenses/geist_ofl.txt'),
    );
  });
  runApp(GlassForgeExample(playground: Playground()));
}

/// A playground for glass_forge: three scenes and a sheet of knobs.
class GlassForgeExample extends StatelessWidget {
  const GlassForgeExample({required this.playground, super.key});

  final Playground playground;

  @override
  Widget build(BuildContext context) {
    return PlaygroundScope(
      playground: playground,
      // Wrap the app once. The engine picks a tier from what the GPU can do,
      // how hot the device is, the frame rate it is actually getting and the
      // user's accessibility settings, and every layer below degrades to
      // match. The tuner's "Quality tier" control pins it instead.
      child: Builder(
        builder: (context) => GlassTierScope(
          requested: PlaygroundScope.of(context).tier,
          child: GlassTheme(
            // The sheet role, lightened: thin blur and the lightest tint
            // step that still clears 3:1 for its labels. The default is
            // thick and "readable" (4.5:1), which is right for a sheet of
            // body text and too frosted for a sheet of controls over a
            // photo you are meant to keep seeing.
            data: GlassThemeData(
              brightness: Brightness.dark,
              surfaces: GlassSurfaces(
                sheet: GlassSurfaceSpec.sheet.copyWith(
                  blur: GlassBlurStep.thin,
                  tint: GlassTintStep.legible,
                ),
              ),
            ),
            child: MaterialApp(
              title: 'Glass Forge',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                brightness: Brightness.dark,
                fontFamily: 'Geist',
                scaffoldBackgroundColor: Tone.ground,
              ),
              home: const Home(),
            ),
          ),
        ),
      ),
    );
  }
}
