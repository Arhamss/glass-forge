import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/glass_shape_clipper.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';
import 'package:glass_forge/src/widgets/glass_presence.dart';

/// One semantic surface, in one line.
///
/// ```dart
/// GlassSurface.navigationBar(child: NavBarContents())
/// ```
///
/// Resolves the role against the enclosing [GlassTheme], the incoming
/// constraints and the scheme, then draws the shadow, the glass and the
/// vibrant label colour that go with it. Still belongs inside a single
/// `GlassLayer` for the whole screen: a layer captures the backdrop once
/// per distinct material among its shapes, so five roles under one layer
/// cost five captures however many surfaces play them, where a layer per
/// surface costs one each.
///
/// On a glass surface already (under [GlassHostScope]) it paints a flat
/// tint of its material instead of glass, so a bar or card placed inside a
/// sheet never stacks glass on glass.
///
/// Under a [GlassPresence], [child] fades with the glass: presence only
/// reaches the refraction, and a label left drawn on glass that has gone
/// would float over whatever now covers it.
class GlassSurface extends StatelessWidget {
  /// Creates a surface for [role].
  const GlassSurface({
    required this.role,
    this.child,
    this.backdrop,
    this.clipBehavior = Clip.antiAlias,
    this.material,
    super.key,
  });

  /// A navigation bar, tab bar or toolbar.
  const GlassSurface.navigationBar({
    Widget? child,
    Color? backdrop,
    Clip clipBehavior = Clip.antiAlias,
    GlassMaterial? material,
    Key? key,
  }) : this(
         role: GlassSurfaceRole.navigationBar,
         child: child,
         backdrop: backdrop,
         clipBehavior: clipBehavior,
         material: material,
         key: key,
       );

  /// A sheet, popover or sidebar.
  const GlassSurface.sheet({
    Widget? child,
    Color? backdrop,
    Clip clipBehavior = Clip.antiAlias,
    GlassMaterial? material,
    Key? key,
  }) : this(
         role: GlassSurfaceRole.sheet,
         child: child,
         backdrop: backdrop,
         clipBehavior: clipBehavior,
         material: material,
         key: key,
       );

  /// A card in the content layer.
  const GlassSurface.card({
    Widget? child,
    Color? backdrop,
    Clip clipBehavior = Clip.antiAlias,
    GlassMaterial? material,
    Key? key,
  }) : this(
         role: GlassSurfaceRole.card,
         child: child,
         backdrop: backdrop,
         clipBehavior: clipBehavior,
         material: material,
         key: key,
       );

  /// A button, toggle, slider or segmented control.
  const GlassSurface.control({
    Widget? child,
    Color? backdrop,
    Clip clipBehavior = Clip.antiAlias,
    GlassMaterial? material,
    Key? key,
  }) : this(
         role: GlassSurfaceRole.control,
         child: child,
         backdrop: backdrop,
         clipBehavior: clipBehavior,
         material: material,
         key: key,
       );

  /// The dimming layer under a modal.
  const GlassSurface.scrim({
    Widget? child,
    Color? backdrop,
    Clip clipBehavior = Clip.antiAlias,
    GlassMaterial? material,
    Key? key,
  }) : this(
         role: GlassSurfaceRole.scrim,
         child: child,
         backdrop: backdrop,
         clipBehavior: clipBehavior,
         material: material,
         key: key,
       );

  /// Which role this surface plays.
  final GlassSurfaceRole role;

  /// Content drawn on the glass.
  final Widget? child;

  /// What is behind this surface, where the app knows.
  ///
  /// Supplying it is what turns the role's adaptation on: a flipping surface
  /// can choose its scheme, and an adapting one can thicken its tint until
  /// labels clear the role's contrast target. Nothing samples this
  /// automatically yet, so leaving it null is the honest default rather than
  /// a missing feature.
  final Color? backdrop;

  /// How [child] is clipped to the resolved shape.
  final Clip clipBehavior;

  /// This surface's material, in place of the one [role] resolves to.
  ///
  /// Null keeps the role's. An app with a look of its own names one here;
  /// the label colour, shadows, shape and motion still come from the role.
  ///
  /// The label colour is resolved for the role's material, not this one,
  /// and a [backdrop] adapts the role's material and label together: an
  /// override replaces only the material, so it does not re-derive
  /// contrast. An override much lighter or darker than the role's own is
  /// the caller's to check for legibility.
  final GlassMaterial? material;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // `biggest` is already infinite on an unbounded axis, and that is
        // the right answer rather than a fallback: a surface that may grow
        // without limit is not a small element, so the size gate demotes it
        // to `adapt`. On a bounded axis this over-estimates — the child may
        // render narrower than its constraint — which errs in the same safe
        // direction. A caller that knows the real size can call
        // `GlassTheme.surfaceOf` with it and do better.
        final style = GlassTheme.surfaceOf(
          context,
          role,
          size: constraints.biggest,
          backdrop: backdrop,
        );

        var content = DefaultTextStyle.merge(
          style: TextStyle(color: style.labelColor),
          child: IconTheme.merge(
            data: IconThemeData(color: style.labelColor),
            child: child ?? const SizedBox.shrink(),
          ),
        );
        // Presence reaches only the refraction. Content left drawn on glass
        // that has faded out would float over whatever now covers it, so it
        // fades with the same animation.
        final presence = GlassPresenceScope.maybeOf(context);
        if (presence != null) {
          content = FadeTransition(opacity: presence, child: content);
        }

        final resolved = material ?? style.material;
        // Already on glass — a bar inside a sheet, say — this surface paints
        // a flat tint of its material rather than stacking a second glass
        // on the first, the same stand-in every control uses there.
        final glass = GlassHostScope.isOnGlass(context)
            ? ClipPath(
                clipper: GlassShapeClipper(style.shape),
                clipBehavior: clipBehavior,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: resolved.tint.withValues(
                      alpha: resolved.tintOpacity,
                    ),
                  ),
                  child: content,
                ),
              )
            : Glass(
                shape: style.shape,
                material: resolved,
                clipBehavior: clipBehavior,
                child: content,
              );

        if (style.shadows.isEmpty) {
          return glass;
        }
        return CustomPaint(
          painter: _GlassShadowPainter(
            shape: style.shape,
            shadows: style.shadows,
          ),
          child: glass,
        );
      },
    );
  }
}

/// Paints a surface's shadows with the surface's own silhouette cut out.
///
/// A [BoxShadow] is drawn as a blurred, *filled* copy of the shape. Under an
/// opaque surface that fill is invisible, which is why every Material
/// elevation gets away with it. Glass is translucent, so the same fill shows
/// straight through the surface it is meant to sit under and reads as a grey
/// slab inside the glass. Clipping the silhouette out leaves only the
/// penumbra, which is the part that was doing the work.
class _GlassShadowPainter extends CustomPainter {
  const _GlassShadowPainter({required this.shape, required this.shadows});

  final GlassShape shape;
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
  bool shouldRepaint(_GlassShadowPainter oldDelegate) =>
      oldDelegate.shape != shape || !listEquals(oldDelegate.shadows, shadows);
}
