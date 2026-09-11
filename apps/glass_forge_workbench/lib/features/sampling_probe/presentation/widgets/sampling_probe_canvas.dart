import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/sampling_probe/presentation/widgets/sampling_probe_animated_glass.dart';
import 'package:glass_forge_workbench/features/sampling_probe/presentation/widgets/sampling_probe_backdrop.dart';
import 'package:glass_forge_workbench/utils/enums/sampling_probe_backdrop_style.dart';
import 'package:glass_forge_workbench/utils/enums/sampling_probe_mode.dart';

/// The probe surface: the high-frequency backdrop, captured by one
/// `GlassLayer` that the animated glass shape refracts.
///
/// [mode] is keyed onto the `GlassLayer` so switching it tears down and
/// rebuilds the layer's `RenderObject` — and with it the shader the layer's
/// `GlassComposition` acquires — rather than leaving a stale shader bound
/// from before the toggle.
///
/// `frost` is forced to zero. `RenderGlassLayer` pushes exactly one
/// `BackdropFilterLayer` clipped to the whole layer's bounds, with blur and
/// the refraction shader composed into that single filter — so a non-zero
/// frost blurs the entire layer, not just the glass shape's silhouette,
/// which would hide the backdrop this probe exists to look at.
class SamplingProbeCanvas extends StatelessWidget {
  /// Creates the probe surface.
  const SamplingProbeCanvas({
    required this.mode,
    required this.backdropStyle,
    required this.edgeRefraction,
    super.key,
  });

  /// Which backdrop-sampling shader the glass layer renders through.
  final SamplingProbeMode mode;

  /// Which backdrop is painted behind the glass shape.
  final SamplingProbeBackdropStyle backdropStyle;

  /// Peak edge displacement fed to the glass material, in logical pixels.
  final double edgeRefraction;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SamplingProbeBackdrop(style: backdropStyle),
        GlassLayer(
          key: ValueKey(mode),
          material: GlassMaterial.regular(
            brightness: Brightness.light,
          ).copyWith(edgeRefraction: edgeRefraction, frost: 0),
          child: const SamplingProbeAnimatedGlass(),
        ),
      ],
    );
  }
}
