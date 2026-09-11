import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/retained_clip_chain.dart';

/// Attaches [root] to a fresh [PipelineOwner] and lays the whole subtree
/// out tightly at [size].
///
/// `RenderObject.getTransformTo` -- what [RetainedClipChain] relies on to
/// map a captured clip into the layer's space -- asserts the render object
/// is attached, and every clip's `paintBounds` needs a real layout to be
/// meaningful.
void _attachAndLayout(RenderBox root, Size size) {
  final owner = PipelineOwner();
  root.attach(owner);
  owner.flushCompositingBits();
  root.layout(BoxConstraints.tight(size));
}

RenderConstrainedBox _leaf() {
  return RenderConstrainedBox(
    additionalConstraints: const BoxConstraints.tightFor(
      width: 20,
      height: 20,
    ),
  );
}

void main() {
  test('collects a RenderClipRRect between shape and layer', () {
    final shape = _leaf();
    final clip = RenderClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: shape,
    );
    final layer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 100,
        height: 100,
      ),
      child: clip,
    );
    _attachAndLayout(layer, const Size(100, 100));

    final chain = RetainedClipChain()..collect(shape, layer);

    expect(chain.clips, hasLength(1));
    final captured = chain.clips.single;
    expect(captured.rect, Offset.zero & clip.size);
    expect(captured.behavior, Clip.antiAlias);
    expect(
      captured.rrect,
      BorderRadius.circular(
        12,
      ).resolve(TextDirection.ltr).toRRect(Offset.zero & clip.size),
    );
    expect(captured.transform, clip.getTransformTo(layer));
  });

  test('collects a RenderClipRect between shape and layer', () {
    final shape = _leaf();
    final clip = RenderClipRect(clipBehavior: Clip.hardEdge, child: shape);
    final layer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 80,
        height: 80,
      ),
      child: clip,
    );
    _attachAndLayout(layer, const Size(80, 80));

    final chain = RetainedClipChain()..collect(shape, layer);

    expect(chain.clips, hasLength(1));
    final captured = chain.clips.single;
    expect(captured.rect, Offset.zero & clip.size);
    expect(captured.rrect, isNull);
    expect(captured.behavior, Clip.hardEdge);
  });

  test('collects nested clips outermost first', () {
    final shape = _leaf();
    final inner = RenderClipRect(child: shape);
    final outer = RenderClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: inner,
    );
    final layer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 100,
        height: 100,
      ),
      child: outer,
    );
    _attachAndLayout(layer, const Size(100, 100));

    final chain = RetainedClipChain()..collect(shape, layer);

    expect(chain.clips, hasLength(2));
    // Outermost (the RRect, nearest the layer) must come first, so it is
    // pushed first and ends up outermost in the re-pushed layer tree too.
    expect(chain.clips[0].rrect, isNotNull);
    expect(chain.clips[1].rrect, isNull);
  });

  test(
    'does not capture a clip above the layer '
    '(regression: walking past the boundary the layer is supposed to be)',
    () {
      final shape = _leaf();
      final betweenClip = RenderClipRect(child: shape);
      final layer = RenderConstrainedBox(
        additionalConstraints: const BoxConstraints.tightFor(
          width: 60,
          height: 60,
        ),
        child: betweenClip,
      );
      final outerClip = RenderClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: layer,
      );
      final root = RenderConstrainedBox(
        additionalConstraints: const BoxConstraints.tightFor(
          width: 100,
          height: 100,
        ),
        child: outerClip,
      );
      _attachAndLayout(root, const Size(100, 100));

      final chain = RetainedClipChain()..collect(shape, layer);

      // Only betweenClip (a RenderClipRect, so rrect is null) may appear;
      // outerClip (a RenderClipRRect, above the layer) must not.
      expect(chain.clips, hasLength(1));
      expect(chain.clips.single.rrect, isNull);
    },
  );

  test('an unrelated ancestor between shape and layer is not captured', () {
    final shape = _leaf();
    final padding = RenderPadding(
      padding: const EdgeInsets.all(4),
      child: shape,
    );
    final layer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 60,
        height: 60,
      ),
      child: padding,
    );
    _attachAndLayout(layer, const Size(60, 60));

    final chain = RetainedClipChain()..collect(shape, layer);

    expect(chain.clips, isEmpty);
  });

  test('collecting again replaces the previous clips, never appends', () {
    final shape = _leaf();
    final clip = RenderClipRect(child: shape);
    final layer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 60,
        height: 60,
      ),
      child: clip,
    );
    _attachAndLayout(layer, const Size(60, 60));

    final chain = RetainedClipChain()
      ..collect(shape, layer)
      ..collect(shape, layer)
      ..collect(shape, layer);

    expect(chain.clips, hasLength(1));
  });

  test('clear discards captured clips', () {
    final shape = _leaf();
    final clip = RenderClipRect(child: shape);
    final layer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 60,
        height: 60,
      ),
      child: clip,
    );
    _attachAndLayout(layer, const Size(60, 60));

    final chain = RetainedClipChain()..collect(shape, layer);
    expect(chain.clips, isNotEmpty);

    chain.clear();

    expect(chain.clips, isEmpty);
  });

  test('matches is true for two chains that captured the same clips', () {
    RetainedClipChain buildChain() {
      final shape = _leaf();
      final clip = RenderClipRect(child: shape);
      final layer = RenderConstrainedBox(
        additionalConstraints: const BoxConstraints.tightFor(
          width: 60,
          height: 60,
        ),
        child: clip,
      );
      _attachAndLayout(layer, const Size(60, 60));
      return RetainedClipChain()..collect(shape, layer);
    }

    final a = buildChain();
    final b = buildChain();

    expect(a.matches(b), isTrue);
    expect(b.matches(a), isTrue);
  });

  test('matches is false when the clip count differs', () {
    final oneClipShape = _leaf();
    final oneClipLayer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 60,
        height: 60,
      ),
      child: RenderClipRect(child: oneClipShape),
    );
    _attachAndLayout(oneClipLayer, const Size(60, 60));
    final oneClip = RetainedClipChain()..collect(oneClipShape, oneClipLayer);

    final twoClipsShape = _leaf();
    final twoClipsLayer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 60,
        height: 60,
      ),
      child: RenderClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: RenderClipRect(child: twoClipsShape),
      ),
    );
    _attachAndLayout(twoClipsLayer, const Size(60, 60));
    final twoClips = RetainedClipChain()
      ..collect(twoClipsShape, twoClipsLayer);

    expect(oneClip.matches(twoClips), isFalse);
    expect(twoClips.matches(oneClip), isFalse);
  });

  test("matches is false when a clip's rect differs", () {
    final smallShape = _leaf();
    final smallLayer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 60,
        height: 60,
      ),
      child: RenderClipRect(child: smallShape),
    );
    _attachAndLayout(smallLayer, const Size(60, 60));
    final small = RetainedClipChain()..collect(smallShape, smallLayer);

    final bigShape = _leaf();
    final bigLayer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 90,
        height: 90,
      ),
      child: RenderClipRect(child: bigShape),
    );
    _attachAndLayout(bigLayer, const Size(90, 90));
    final big = RetainedClipChain()..collect(bigShape, bigLayer);

    expect(small.matches(big), isFalse);
  });

  test("matches is false when a clip's behavior differs", () {
    final hardEdgeShape = _leaf();
    final hardEdgeLayer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 60,
        height: 60,
      ),
      child: RenderClipRect(clipBehavior: Clip.hardEdge, child: hardEdgeShape),
    );
    _attachAndLayout(hardEdgeLayer, const Size(60, 60));
    final hardEdge = RetainedClipChain()
      ..collect(hardEdgeShape, hardEdgeLayer);

    final antiAliasShape = _leaf();
    final antiAliasLayer = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(
        width: 60,
        height: 60,
      ),
      child: RenderClipRect(child: antiAliasShape),
    );
    _attachAndLayout(antiAliasLayer, const Size(60, 60));
    final antiAlias = RetainedClipChain()
      ..collect(antiAliasShape, antiAliasLayer);

    expect(hardEdge.matches(antiAlias), isFalse);
  });

  test(
    "composing the chain's transforms, outermost first, reconstructs the "
    "innermost clip's true transform to the layer even when clips sit at "
    'a non-identity offset from each other '
    '(regression: each transform was absolute to the layer, so nesting '
    'them applied the path two clips share twice)',
    () {
      final shape = _leaf();
      final innerClip = RenderClipRect(child: shape);
      final betweenClips = RenderPadding(
        padding: const EdgeInsets.only(left: 10, top: 10),
        child: innerClip,
      );
      final outerClip = RenderClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: betweenClips,
      );
      final aboveOuterClip = RenderPadding(
        padding: const EdgeInsets.only(left: 20, top: 20),
        child: outerClip,
      );
      final layer = RenderConstrainedBox(
        additionalConstraints: const BoxConstraints.tightFor(
          width: 200,
          height: 200,
        ),
        child: aboveOuterClip,
      );
      _attachAndLayout(layer, const Size(200, 200));

      final chain = RetainedClipChain()..collect(shape, layer);
      expect(chain.clips, hasLength(2));

      // The same left-to-right fold _pushGlassLayers uses when it composes
      // every clip's transform to find (and then undo) the net shift left
      // once the innermost clip is reached.
      var composed = Matrix4.identity();
      for (final clip in chain.clips) {
        composed = composed.multiplied(clip.transform);
      }

      expect(composed, innerClip.getTransformTo(layer));
      // The Padding between the two clips means this would fail if either
      // clip's transform were absolute to the layer instead of relative to
      // its own parent in the chain: the 20-logical-pixel offset above
      // outerClip would then be counted twice.
      expect(composed, isNot(Matrix4.identity()));
    },
  );

  test(
    'a RenderClipRect with clipBehavior none contributes no clip',
    () {
      final shape = _leaf();
      final clip = RenderClipRect(clipBehavior: Clip.none, child: shape);
      final layer = RenderConstrainedBox(
        additionalConstraints: const BoxConstraints.tightFor(
          width: 60,
          height: 60,
        ),
        child: clip,
      );
      _attachAndLayout(layer, const Size(60, 60));

      final chain = RetainedClipChain()..collect(shape, layer);

      // Not just "no crash": a clip this chain still tried to re-push
      // would be pointless work at best, since pushClipRect/pushClipRRect
      // already no-op for Clip.none -- but every entry here also carries a
      // pushTransform, which is not free.
      expect(chain.clips, isEmpty);
    },
  );

  test(
    "a RenderClipRect's custom clipper narrows the captured rect",
    () {
      final shape = _leaf();
      final clip = RenderClipRect(
        clipper: const _FixedRectClipper(Rect.fromLTWH(0, 0, 30, 30)),
        child: shape,
      );
      final layer = RenderConstrainedBox(
        additionalConstraints: const BoxConstraints.tightFor(
          width: 60,
          height: 60,
        ),
        child: clip,
      );
      _attachAndLayout(layer, const Size(60, 60));

      final chain = RetainedClipChain()..collect(shape, layer);

      expect(chain.clips, hasLength(1));
      // Not clip.paintBounds (0,0,60,60) -- the clipper's approximate rect,
      // which describeApproximatePaintClip is the one to know about.
      expect(chain.clips.single.rect, const Rect.fromLTWH(0, 0, 30, 30));
    },
  );
}

/// A [CustomClipper] that always reports the same approximate rect,
/// regardless of the size it is asked to clip.
class _FixedRectClipper extends CustomClipper<Rect> {
  const _FixedRectClipper(this.rect);

  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  Rect getApproximateClipRect(Size size) => rect;

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}
