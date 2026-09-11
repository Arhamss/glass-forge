import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/material/glass_profile.dart';

const _edgeBand = MatteRequest(
  devicePixelRatio: 3,
  maxDisplacement: 86.4,
  edgeRefraction: 82.3,
  refractionSpread: 0,
  antialiasWidth: 0.5,
);

void main() {
  test('the default request is the edge band, reading no thickness', () {
    // Every request built before the dome existed must keep baking what it
    // always baked.
    expect(_edgeBand.profile, GlassProfile.edgeBand);
    expect(_edgeBand.profileCode, 0);
    expect(_edgeBand.thickness, 0);
  });

  test('the profile and the thickness are part of what a matte is', () {
    // A layer skips the bake when the request is unchanged, so a field
    // baked into the matte but missing from equality leaves the old matte
    // on screen after it changes.
    const dome = MatteRequest(
      devicePixelRatio: 3,
      maxDisplacement: 86.4,
      edgeRefraction: 82.3,
      refractionSpread: 0,
      antialiasWidth: 0.5,
      profile: GlassProfile.dome,
      thickness: 24,
    );
    const edgeBandAtTheSameThickness = MatteRequest(
      devicePixelRatio: 3,
      maxDisplacement: 86.4,
      edgeRefraction: 82.3,
      refractionSpread: 0,
      antialiasWidth: 0.5,
      thickness: 24,
    );
    const thicker = MatteRequest(
      devicePixelRatio: 3,
      maxDisplacement: 86.4,
      edgeRefraction: 82.3,
      refractionSpread: 0,
      antialiasWidth: 0.5,
      profile: GlassProfile.dome,
      thickness: 36,
    );
    expect(dome, isNot(edgeBandAtTheSameThickness));
    expect(dome.hashCode, isNot(edgeBandAtTheSameThickness.hashCode));
    expect(thicker, isNot(dome));
    expect(dome.profileCode, 1);
  });
}
