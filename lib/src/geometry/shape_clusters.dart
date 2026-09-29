import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

/// Shapes grouped so that no two groups' matte regions touch. Shapes in one
/// blend group, or whose padded bounds overlap, share a cluster.
///
/// This is what lets a pass carry more than `kMaxShapes`. The cap is the
/// geometry shader's uniform budget -- twelve floats a shape, 96 in all --
/// and it stays; what changes is that a pass is no longer one draw. Each
/// cluster is drawn on its own, clipped to [bounds], with only its own
/// shapes in the uniforms, so the cap now applies per cluster.
@immutable
class ShapeCluster {
  /// Creates a cluster.
  const ShapeCluster({required this.shapes, required this.bounds});

  /// The cluster's shapes, in registration order.
  ///
  /// Order is load-bearing: the fold in `common/scene.glsl` smooth-mins a
  /// blend group in registration order, the quadratic smooth-min is not
  /// associative, and a shape's marker says only "opens a group" or
  /// "continues the one in progress" -- so a reordered group would blend
  /// differently, or join the wrong opener altogether.
  final List<ShapeGeometry> shapes;

  /// The union of the members' padded bounds, in layer-space physical
  /// pixels, rounded out to whole pixels.
  ///
  /// Whole pixels because both producers clip their draw to it, and the
  /// matte allocation starts on a whole pixel (`expandToPixelBuckets`
  /// floors its origin): an integral rect covers exactly the same texels on
  /// every backend, so no texel is drawn by two clusters and the runtime
  /// and Flutter GPU producers clip identically.
  final Rect bounds;
}

/// How far past its bounds a shape's matte has to be exact, in physical
/// pixels -- the padding [clusterShapes] needs for [request].
///
/// Not how far the bake *writes* past a shape. The bake encodes a real
/// distance out to `maxDisplacement` (see `gfBakeMatte` in
/// `common/matte_pass.glsl`), but nothing downstream reads most of that:
/// the final pass (`shaders/final_render.frag`) samples the matte once, at
/// the fragment's own position -- displacement moves the *backdrop* read,
/// never the matte read -- and returns transparent wherever the decoded
/// distance leaves no coverage, before the normal, the magnitude, the
/// shading or the glow are looked at. So outside a shape the matte only
/// has to be right across the coverage ramp. Padding by the displacement
/// reach instead (about 60 px at 3x) merged a Control-Centre grid of tiles
/// with 12 px gaps into one cluster and dropped every tile past the eighth.
///
/// What a cluster's draw must still get right, term by term:
///
///  * `antialiasWidth`: the coverage ramp, the same margin
///    `GlassScene.bounds` gives the matte allocation itself -- coverage
///    past it is already cut off at a layer's top and left edges;
///  * one pixel: the matte is filtered, so a covered fragment blends the
///    encodings of texels up to a pixel beyond the ramp, and a texel
///    cleared to "outside" there would thin the fringe;
///  * one more: the normal is a central difference a pixel either side of
///    each of those texels, and those samples must not reach a shape the
///    draw does not carry;
///  * one of margin, so the two sides of a gap -- each padded by this --
///    never both claim the same pixel after rounding.
///
/// Outside those texels a separately drawn cluster can only read *further*
/// from glass than the whole scene would (a cleared texel is "outside"; a
/// fold over fewer groups is a min over fewer terms), so it can never add
/// coverage anywhere.
///
/// The dome no longer widens it. Its steering proxy rounds corners by up
/// to three displacements, so under the old single draw a separate shape
/// a few pixels away could win the steering fold at a dome's corner and
/// pull that corner toward the *neighbour's* core -- cross-talk between two
/// surfaces the caller never blended. Drawn apart, each dome steers by its
/// own proxy, as a separate surface should. Blended shapes are unaffected:
/// a blend group is always one cluster.
double clusterPadding(MatteRequest request) =>
    request.antialiasWidth + _clusterPaddingPixels;

/// The three whole pixels [clusterPadding] adds past the coverage ramp:
/// the filtered read, the normal's central difference, and the margin
/// between two sides of a gap, one each, as its doc lists them.
const double _clusterPaddingPixels = 3;

/// The most [clusterShapes] widens one shape's padding for anisotropy.
///
/// A shape squashed nearly flat mid-animation would otherwise pad itself
/// by thousands of pixels and pull every other shape into its cluster --
/// and a cluster past `kMaxShapes` drops shapes outright, which is far
/// worse than what the clamp costs: past a 4:1 stretch, the outermost
/// texels of the antialiased fringe along the long axis may be cleared to
/// "outside", thinning that fringe by a fraction of a pixel.
const double _maxStretch = 4;

/// Groups [shapes] into clusters that can be baked as separate draws.
///
/// Two shapes share a cluster when they are in one blend group, or when
/// their [ShapeGeometry.layerBounds], each grown by [padding] (see
/// [clusterPadding]), overlap. Clusters whose own bounds would then overlap
/// are merged too, until none do: two chains of shapes can interleave so
/// that no pair of shapes is close but the rects the clusters are clipped
/// to still cross, and a later cluster's draw would overwrite the earlier
/// one's texels there.
///
/// A blend group is found the way the fold finds it -- a shape whose
/// marker is negative opens one and every following non-negative marker
/// continues it -- rather than by marker value, because that is the only
/// grouping the shader actually performs. Keeping whole groups together,
/// in registration order, is what makes each cluster's fold reproduce the
/// whole scene's fold wherever that cluster draws.
///
/// Each shape's padding is widened by how anisotropically its basis
/// stretches it (capped at [_maxStretch]): the shader scales a local
/// distance into layer pixels by the basis's *smallest* stretch
/// ([ShapeGeometry.distanceScale]), so along the longest axis it reports a
/// distance shorter than the true one, and a matte region reaches that
/// much further in layer space.
///
/// Clusters come back ordered by their first member's registration index.
List<ShapeCluster> clusterShapes(
  List<ShapeGeometry> shapes, {
  required double padding,
}) {
  final count = shapes.length;
  if (count == 0) {
    return const <ShapeCluster>[];
  }

  final parent = List<int>.generate(count, (i) => i);
  int find(int i) {
    var root = i;
    while (parent[root] != root) {
      root = parent[root];
    }
    // Path compression, so repeated merges stay near-linear.
    var node = i;
    while (parent[node] != root) {
      final next = parent[node];
      parent[node] = root;
      node = next;
    }
    return root;
  }

  void union(int a, int b) {
    final rootA = find(a);
    final rootB = find(b);
    if (rootA == rootB) {
      return;
    }
    // The smaller index stays the root, so a cluster's root is always its
    // first-registered member.
    if (rootA < rootB) {
      parent[rootB] = rootA;
    } else {
      parent[rootA] = rootB;
    }
  }

  // Blend groups, as the fold reads them. A leading run of continuations
  // with no opener folds together from the fold's initial state, so it too
  // is one group -- anchored on shape 0, which is where `opener` starts.
  var opener = 0;
  for (var i = 0; i < count; i++) {
    if (shapes[i].blendMarker < 0) {
      opener = i;
    } else {
      union(i, opener);
    }
  }

  final padded = <Rect>[
    for (final shape in shapes)
      shape.layerBounds.inflate(padding * _stretchOf(shape)),
  ];
  for (var a = 0; a < count; a++) {
    for (var b = a + 1; b < count; b++) {
      if (padded[a].overlaps(padded[b])) {
        union(a, b);
      }
    }
  }

  // Merge clusters whose clip rects overlap, until none do. Each pass
  // either merges at least two clusters or stops, so this terminates in at
  // most `count` passes.
  while (true) {
    final bounds = <int, Rect>{};
    for (var i = 0; i < count; i++) {
      final root = find(i);
      final existing = bounds[root];
      bounds[root] = existing == null
          ? padded[i]
          : existing.expandToInclude(padded[i]);
    }
    final roots = bounds.keys.toList();
    var merged = false;
    for (var a = 0; a < roots.length && !merged; a++) {
      for (var b = a + 1; b < roots.length; b++) {
        if (_roundOut(bounds[roots[a]]!)
            .overlaps(_roundOut(bounds[roots[b]]!))) {
          union(roots[a], roots[b]);
          merged = true;
          break;
        }
      }
    }
    if (!merged) {
      final members = <int, List<ShapeGeometry>>{};
      for (var i = 0; i < count; i++) {
        (members[find(i)] ??= <ShapeGeometry>[]).add(shapes[i]);
      }
      final ordered = members.keys.toList()..sort();
      return <ShapeCluster>[
        for (final root in ordered)
          ShapeCluster(
            shapes: List<ShapeGeometry>.unmodifiable(members[root]!),
            bounds: _roundOut(bounds[root]!),
          ),
      ];
    }
  }
}

/// [rect] grown outward to whole pixels.
Rect _roundOut(Rect rect) => Rect.fromLTRB(
  rect.left.floorToDouble(),
  rect.top.floorToDouble(),
  rect.right.ceilToDouble(),
  rect.bottom.ceilToDouble(),
);

/// How much further [shape]'s matte reaches along its longest axis than
/// its distance field says, as a factor: the ratio of the basis's largest
/// stretch to its smallest, clamped to `[1, _maxStretch]`.
///
/// Computed from the inverse basis, whose singular values are the
/// reciprocals of the forward basis's -- so the ratio is the same. The
/// closed form is [ShapeGeometry.minimumSingularValue]'s: for a 2x2 matrix
/// the squared singular values are `(trace ± sqrt(discriminant)) / 2` of
/// `MᵀM`.
double _stretchOf(ShapeGeometry shape) {
  final m = shape.inverseBasis;
  final trace = m[0] * m[0] + m[1] * m[1] + m[2] * m[2] + m[3] * m[3];
  final determinant = m[0] * m[3] - m[1] * m[2];
  final root = math.sqrt(
    math.max(0, trace * trace - 4 * determinant * determinant),
  );
  final smallest = (trace - root) * 0.5;
  final largest = (trace + root) * 0.5;
  if (!(smallest > 0) || !largest.isFinite) {
    // Degenerate: the shape draws nothing (see ShapeGeometry.layerBounds),
    // so there is no fringe to protect.
    return 1;
  }
  return math.sqrt(largest / smallest).clamp(1.0, _maxStretch);
}
