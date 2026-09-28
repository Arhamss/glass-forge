import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/shape_clusters.dart';
import 'package:glass_forge/src/material/glass_profile.dart';
import 'package:glass_forge/src/scene/blend_group_link.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

const _request = MatteRequest(
  devicePixelRatio: 1,
  maxDisplacement: 32,
  edgeRefraction: 27.42,
  refractionSpread: 0,
  antialiasWidth: 0.5,
);

final double _padding = clusterPadding(_request);

/// A 40 px oval with its top-left corner at [at].
///
/// Ungrouped unless [marker] says otherwise: a shape outside every blend
/// group opens a group of its own (`RenderGlassShape._blendMarker`), and
/// `ShapeGeometry.resolve`'s default marker of 0 is a *continuation*, which
/// would fold every shape here into one group.
ShapeGeometry _oval(Offset at, {double? marker}) {
  return ShapeGeometry.resolve(
    shape: const GlassOval(),
    size: const Size(40, 40),
    toLayer: Matrix4.translationValues(at.dx, at.dy, 0),
    devicePixelRatio: 1,
    blendMarker: marker ?? encodeBlendMarker(startsGroup: true, blend: 0),
  );
}

void main() {
  test('the padding is the coverage ramp, not the displacement reach', () {
    // The final pass reads the matte only at a fragment's own position and
    // only where it has coverage, so a cluster needs to be exact across the
    // antialias ramp plus the filter's and the normal's pixel -- not out to
    // maxDisplacement, which merged a 12 px-gapped tile grid into one
    // cluster past the per-draw cap.
    expect(_padding, 0.5 + 3);
    expect(_padding, lessThan(_request.maxDisplacement));
    // The same for a dome: separate domes do not steer one another.
    const dome = MatteRequest(
      devicePixelRatio: 1,
      maxDisplacement: 32,
      edgeRefraction: 30,
      refractionSpread: 0,
      antialiasWidth: 0.5,
      profile: GlassProfile.dome,
    );
    expect(clusterPadding(dome), _padding);
  });

  test('tiles 12 px apart are separate clusters', () {
    final shapes = <ShapeGeometry>[
      for (var i = 0; i < 12; i++)
        _oval(Offset((i % 4) * 52.0, (i ~/ 4) * 52.0)),
    ];
    expect(clusterShapes(shapes, padding: _padding), hasLength(12));
  });

  test('twelve separate shapes are twelve clusters', () {
    // 100 px of clear space between neighbours, more than two paddings.
    final shapes = <ShapeGeometry>[
      for (var i = 0; i < 12; i++) _oval(Offset(i * 140.0, 0)),
    ];
    final clusters = clusterShapes(shapes, padding: _padding);

    expect(clusters, hasLength(12));
    for (var i = 0; i < 12; i++) {
      expect(clusters[i].shapes, <ShapeGeometry>[shapes[i]]);
    }
    // No two clusters may share a texel: each draw is clipped to its
    // bounds, and a later draw overwrites an earlier one.
    for (var a = 0; a < clusters.length; a++) {
      for (var b = a + 1; b < clusters.length; b++) {
        expect(clusters[a].bounds.overlaps(clusters[b].bounds), isFalse);
      }
    }
  });

  test("a cluster's bounds cover its shapes' padded bounds", () {
    final shape = _oval(const Offset(10.25, 20.75));
    final cluster = clusterShapes(<ShapeGeometry>[shape], padding: _padding);

    final padded = shape.layerBounds.inflate(_padding);
    final bounds = cluster.single.bounds;
    expect(bounds.left, lessThanOrEqualTo(padded.left));
    expect(bounds.top, lessThanOrEqualTo(padded.top));
    expect(bounds.right, greaterThanOrEqualTo(padded.right));
    expect(bounds.bottom, greaterThanOrEqualTo(padded.bottom));
    // Whole pixels, so both producers clip to the same texels.
    for (final edge in <double>[
      bounds.left,
      bounds.top,
      bounds.right,
      bounds.bottom,
    ]) {
      expect(edge, edge.roundToDouble());
    }
  });

  test('two overlapping shapes are one cluster', () {
    final shapes = <ShapeGeometry>[
      _oval(Offset.zero),
      _oval(const Offset(20, 0)),
    ];
    final clusters = clusterShapes(shapes, padding: _padding);

    expect(clusters, hasLength(1));
    expect(clusters.single.shapes, shapes);
  });

  test('shapes whose mattes would meet share a cluster', () {
    // Not touching, but closer than two paddings: the gap between them is
    // baked from both at once.
    final shapes = <ShapeGeometry>[
      _oval(Offset.zero),
      _oval(Offset(40 + _padding, 0)),
    ];
    expect(clusterShapes(shapes, padding: _padding), hasLength(1));
  });

  test(
    'three shapes in one blend group far apart are one cluster, in '
    'registration order',
    () {
      final opener = _oval(
        const Offset(1000, 0),
        marker: encodeBlendMarker(startsGroup: true, blend: 20),
      );
      final second = _oval(
        Offset.zero,
        marker: encodeBlendMarker(startsGroup: false, blend: 20),
      );
      final third = _oval(
        const Offset(0, 1000),
        marker: encodeBlendMarker(startsGroup: false, blend: 20),
      );
      final clusters = clusterShapes(<ShapeGeometry>[
        opener,
        second,
        third,
      ], padding: _padding);

      expect(clusters, hasLength(1));
      // The opener first: the fold reads "continues the group in progress",
      // so a continuation ahead of its opener joins nothing.
      expect(clusters.single.shapes, <ShapeGeometry>[opener, second, third]);
    },
  );

  test('a continuation belongs to the latest opener before it', () {
    // The fold's grouping, not the marker's value: `b` continues `a`'s
    // group, and `c` opens its own, far from both.
    final a = _oval(
      Offset.zero,
      marker: encodeBlendMarker(startsGroup: true, blend: 20),
    );
    final b = _oval(
      const Offset(1000, 0),
      marker: encodeBlendMarker(startsGroup: false, blend: 20),
    );
    final c = _oval(const Offset(0, 1000));
    final clusters = clusterShapes(<ShapeGeometry>[
      a,
      b,
      c,
    ], padding: _padding);

    expect(clusters, hasLength(2));
    expect(clusters[0].shapes, <ShapeGeometry>[a, b]);
    expect(clusters[1].shapes, <ShapeGeometry>[c]);
  });

  test('a cluster whose bounds would cross another absorbs it', () {
    // A blend group at two opposite corners spans a rect that contains a
    // lone shape at a third corner, though no two shapes are near. Drawn
    // separately, one clip would overwrite the other's texels.
    final corner = _oval(
      Offset.zero,
      marker: encodeBlendMarker(startsGroup: true, blend: 20),
    );
    final lone = _oval(const Offset(600, 0));
    final opposite = _oval(
      const Offset(600, 600),
      marker: encodeBlendMarker(startsGroup: false, blend: 20),
    );
    // Registration order puts the lone shape between the opener and its
    // continuation only in space, not in the list: the list is
    // corner, opposite, lone, so the group stays whole.
    final clusters = clusterShapes(<ShapeGeometry>[
      corner,
      opposite,
      lone,
    ], padding: _padding);

    expect(clusters, hasLength(1));
    expect(clusters.single.shapes, <ShapeGeometry>[corner, opposite, lone]);
  });

  test('a stretched shape pads by how far its matte really reaches', () {
    // Stretched 2:1, the shader scales distance by the smaller stretch, so
    // along the long axis the matte reaches twice as far as the padding.
    final stretched = ShapeGeometry.resolve(
      shape: const GlassOval(),
      size: const Size(40, 40),
      toLayer: Matrix4.diagonal3Values(2, 1, 1),
      devicePixelRatio: 1,
      blendMarker: encodeBlendMarker(startsGroup: true, blend: 0),
    );
    // Further than two plain paddings, nearer than the stretched one's two
    // plus the neighbour's one.
    final neighbour = _oval(
      Offset(stretched.layerBounds.right + 2.5 * _padding, 0),
    );

    expect(
      clusterShapes(<ShapeGeometry>[stretched, neighbour], padding: _padding),
      hasLength(1),
    );
  });

  test('an empty list is no clusters', () {
    expect(clusterShapes(const <ShapeGeometry>[], padding: _padding), isEmpty);
  });
}
