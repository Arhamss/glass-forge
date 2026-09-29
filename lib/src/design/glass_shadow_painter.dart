import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';

/// Paints a surface's shadows with the surface's own silhouette cut out.
///
/// A [BoxShadow] is drawn as a blurred, *filled* copy of the shape. Under an
/// opaque surface that fill is invisible, which is why every Material
/// elevation gets away with it. Glass is translucent, so the same fill shows
/// straight through the surface it is meant to sit under and reads as a grey
/// slab inside the glass. Clipping the silhouette out leaves only the
/// penumbra, which is the part that was doing the work.
///
/// Internal to this package; not exported. `GlassSurface` draws its glass
/// over one, and `GlassTabBar` its painted, semi-opaque body.
class GlassShadowPainter extends CustomPainter {
  /// Creates a painter for [shadows] around [shape].
  const GlassShadowPainter({required this.shape, required this.shadows});

  /// The silhouette the shadows fall from, and are cut out of.
  final GlassShape shape;

  /// The shadows, as a depth token resolves them.
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final path = shape.toBorder(size).getOuterPath(Offset.zero & size);

    // How far outside the surface any of these shadows can reach. A Gaussian
    // mask filter is effectively dead by three sigma, and `blurSigma` is
    // `blurRadius / 2`, so the reach is 1.5 blur radii plus however far the
    // shadow was offset. Under-estimating here would clip a shadow's own
    // tail off with a hard edge.
    var reach = 0.0;
    for (final shadow in shadows) {
      final offset = shadow.offset.distance;
      final extent = shadow.blurRadius * 1.5 + shadow.spreadRadius + offset;
      if (extent > reach) {
        reach = extent;
      }
    }

    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(reach)),
      path,
    );

    canvas
      ..save()
      ..clipPath(outside);
    for (final shadow in shadows) {
      canvas.drawPath(
        path.shift(shadow.offset),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GlassShadowPainter oldDelegate) =>
      oldDelegate.shape != shape || !listEquals(oldDelegate.shadows, shadows);
}
