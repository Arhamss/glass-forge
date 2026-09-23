import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/index_page.dart';
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

/// A 33-entry catalogue, index to detail, over one photograph.
///
/// One, not the five the example ships: the index and every entry page
/// share `catalogueBackdropPhoto`, so paging between them never swaps the
/// picture out from under the glass. The other four still have their
/// backdrop colours measured in `backdrop_info.dart`, unpainted since the
/// catalogue replaced the scenes.
///
/// Everything on screen is this package's own API. There is no wrapper
/// layer between the reader and `GlassLayer`, `Glass`, `GlassMaterial`,
/// `InteractiveGlass` and `GlassSurface` — where the example needs a widget
/// of its own, it is a painted control, and it says so.
class GlassForgeExample extends StatelessWidget {
  const GlassForgeExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap the app once. The engine resolves a tier from four inputs — what
    // the GPU can do, how hot the device is, what frame rate it is actually
    // achieving, and the user's accessibility settings — and every layer
    // below degrades to match. Without this, Reduce Transparency and
    // Increase Contrast change nothing at all.
    return GlassTierScope(
      // The design system, with two numbers moved. Naming one field of one
      // scale leaves every other token at its default, which is the point
      // of having them: the app is saying "my panels are less round than
      // yours", not restating a theme.
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
          home: const CatalogueIndexPage(),
        ),
      ),
    );
  }
}
