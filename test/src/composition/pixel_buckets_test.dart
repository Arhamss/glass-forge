import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/pixel_buckets.dart';

void main() {
  group('snapToPixel', () {
    test('rounds half-up consistently on both sides of zero', () {
      // floor(x + 0.5) rather than round(): round() rounds half away from
      // zero, so a matte straddling the origin changes size by a pixel as it
      // crosses, and the backdrop target reallocates.
      expect(snapToPixel(0.5, 1), 1);
      expect(snapToPixel(-0.5, 1), 0);
      expect(snapToPixel(-1.5, 1), -1);
    });

    test('snaps in device pixels, not logical ones', () {
      expect(snapToPixel(1.4, 2), 3);
    });
  });

  group('bucketDimension', () {
    test('rounds up to the bucket size', () {
      expect(bucketDimension(1), 64);
      expect(bucketDimension(64), 64);
      expect(bucketDimension(65), 128);
    });

    test('keeps zero at zero', () {
      expect(bucketDimension(0), 0);
    });
  });

  test('expandToPixelBuckets is stable across sub-pixel jitter', () {
    // The whole point: two rects that differ only by a fraction of a pixel
    // must produce the same allocation, or the render target thrashes.
    final a = expandToPixelBuckets(const Rect.fromLTWH(0, 0, 100, 100));
    final b = expandToPixelBuckets(const Rect.fromLTWH(0.3, 0.4, 100, 100));
    expect(a.size, b.size);
  });
}
