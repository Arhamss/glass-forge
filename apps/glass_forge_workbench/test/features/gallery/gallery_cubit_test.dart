import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/cubit/gallery_state.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';

void main() {
  group('GalleryCubit', () {
    test('picking a role takes the size that role really ships at', () {
      final cubit = GalleryCubit()
        ..setShortSide(210)
        ..setRole(GlassSurfaceRole.control);

      expect(cubit.state.shortSide, 44);
      addTearDown(cubit.close);
    });

    test('the size slider drives a navigation bar across the flip gate', () {
      final cubit = GalleryCubit()
        ..setRole(GlassSurfaceRole.navigationBar)
        ..setShortSide(52);

      expect(cubit.state.adaptation, GlassAdaptation.flip);

      // 96 is the gate itself, and the rule is "at or below", so the rung
      // above it is where the demotion has to happen.
      cubit.setShortSide(97);
      expect(cubit.state.adaptation, GlassAdaptation.adapt);
      addTearDown(cubit.close);
    });
  });

  group('GalleryState', () {
    test('a flipping surface stops listening to the app scheme', () {
      // Both readings are taken at a size below the gate, so the only
      // thing separating the two roles is the adaptation their spec
      // allows.
      const state = GalleryState(shortSide: 60);

      expect(state.ignoresAmbientScheme(GlassSurfaceRole.navigationBar),
          isTrue);
      expect(state.ignoresAmbientScheme(GlassSurfaceRole.card), isFalse);
    });

    test('a flipping surface starts listening again once it is large', () {
      const small = GalleryState(shortSide: 60);
      const large = GalleryState(shortSide: 200);

      expect(small.ignoresAmbientScheme(GlassSurfaceRole.navigationBar),
          isTrue);
      expect(large.ignoresAmbientScheme(GlassSurfaceRole.navigationBar),
          isFalse);
    });

    test('every backdrop the rail offers resolves every role', () {
      for (final backdrop in GlassBackdrop.values) {
        for (final role in GlassSurfaceRole.values) {
          final state = GalleryState(role: role, backdrop: backdrop);
          for (final ambient in Brightness.values) {
            final style = state.styleFor(ambient);
            expect(
              style.labelContrast,
              isNotNull,
              reason: 'a backdrop is always supplied here, so the contrast '
                  'a surface promises is always measurable',
            );
            expect(style.material.tintOpacity, inInclusiveRange(0, 1));
          }
        }
      }
    });

    test('the readouts agree with the size the stage really lays out', () {
      // The stage clamps a role's nominal width to the pane it is drawn
      // in; the readouts are computed from the nominal width. The whole
      // screen is dishonest if those two ever reach different verdicts,
      // so this walks every role at every pane width a phone can offer.
      const paneWidths = <double>[288, 343, 430];
      const heights = <double>[40, 52, 95, 96, 97, 132, 180, 220];

      for (final role in GlassSurfaceRole.values) {
        for (final height in heights) {
          final state = GalleryState(role: role, shortSide: height);
          final nominal = state.adaptationOf(role);
          for (final paneWidth in paneWidths) {
            final laidOut = GalleryState.surfaces.of(role).adaptationFor(
              Size(math.min(state.sizeOf(role).width, paneWidth), height),
              maxShortSide: GalleryState.tokens.flipMaxShortSide,
            );
            expect(
              laidOut,
              nominal,
              reason: '${role.name} at ${height}px in a ${paneWidth}px pane',
            );
          }
        }
      }
    });
  });
}
