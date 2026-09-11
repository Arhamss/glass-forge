// Retained ancestor clips.
//
// Scrolling moves material through a viewport, not the viewport through the
// material. A clip captured *inside* a layer that moves travels with the
// content and stops clipping, so any such clip has to be re-pushed outside
// the moving layer instead.
//
// Scope, established empirically rather than assumed: that only applies to
// clips a caller nests *between* a `GlassLayer` and one of its `Glass`
// shapes. A clip that is an ancestor of the `GlassLayer` -- an enclosing
// `ListView`'s viewport, or a `ClipRRect` wrapped around the whole layer --
// needs nothing done to it here, because its clip layer is already pushed
// in the compositor's layer tree before `RenderGlassLayer.paint` runs and
// so already encloses the backdrop pass. Two render tests in
// `retained_clip_chain_test.dart` pin that, each verified to go red when
// the ancestor's own clipping is switched off: "an ancestor clip outside
// the layer already bounds the backdrop without the retained chain" and "a
// scrolling viewport's own clip already bounds the backdrop of a glass
// layer inside it".

import 'package:flutter/rendering.dart';

/// One ancestor clip, captured so it can be re-pushed.
class RetainedClip {
  /// Creates a captured clip.
  RetainedClip({
    required this.rect,
    required this.behavior,
    required this.transform,
    this.rrect,
    this.path,
  });

  /// The clip's bounds, in the clipping node's own local space.
  final Rect rect;

  /// The rounded form, when the ancestor clipped with one.
  final RRect? rrect;

  /// The path form, when the ancestor clipped with one.
  ///
  /// Always `null` today: a `RenderClipPath` is retained as its bounding
  /// [rect] instead, since re-pushing its actual path would need the same
  /// `CustomClipper<Path>.getClip` call the node itself makes, and this
  /// chain has no hook to be told when that clipper's inputs change and the
  /// cached path goes stale. Kept as part of this type -- rather than
  /// dropped -- so a future producer that does have such a hook can start
  /// populating it without a breaking change to callers matching on it.
  final Path? path;

  /// How the ancestor clipped.
  final Clip behavior;

  /// Maps a point in the clipping node's local space into its immediate
  /// parent's local space in the chain: the next clip out (the previous
  /// entry in [RetainedClipChain.clips], since that list is outermost
  /// first), or the layer's own local space for the outermost clip.
  ///
  /// Deliberately relative to the chain, not absolute to the layer:
  /// composing two absolute-to-layer transforms by nesting them (as
  /// re-pushing them requires) would apply whatever portion of the render
  /// tree path they share -- every ancestor between the more-nested clip
  /// and the layer -- twice.
  final Matrix4 transform;
}

/// The ancestor clips that must survive between a glass layer and its
/// content, re-pushed outside the layer's own moving offset.
///
/// A glass layer paints its backdrop pass first and its children inside it.
/// Any clip a caller nests between the layer and one of its shapes is
/// therefore pushed *inside* that backdrop pass, where it bounds the
/// children but not the region the filter samples and fills -- which is how
/// glass ends up drawing outside the box it was meant to stay in.
///
/// Re-pushing those clips outside the backdrop pass keeps them still while
/// the material moves through them, which is the physically correct
/// arrangement: scrolling moves material through a viewport, not the
/// viewport through the material.
///
/// This chain walks only between a `GlassLayer` and one of its `Glass`
/// shapes, as in `GlassLayer(child: ClipRRect(child: Glass(...)))`. It does
/// **not** walk past the layer to clips that are the layer's own ancestors,
/// such as an enclosing `ListView`'s viewport or an outer `ClipRRect`
/// wrapping the whole `GlassLayer`, and it deliberately does not need to --
/// see this file's header for the scope finding and the two render tests
/// that established it.
class RetainedClipChain {
  final List<RetainedClip> _clips = <RetainedClip>[];

  /// The captured clips, outermost first.
  List<RetainedClip> get clips => List<RetainedClip>.unmodifiable(_clips);

  /// Discards any previously captured clips.
  ///
  /// For a layer with no registered shapes: there is no shape to walk up
  /// from, so there is nothing to clip.
  void clear() => _clips.clear();

  /// Walks from [shape] up to [layer], capturing every clip on the way.
  ///
  /// [shape] and [layer] must be attached to the same render tree, with
  /// [layer] an ancestor of [shape] -- the arrangement every registered
  /// glass scene shape already satisfies. Clips found between them (for
  /// example a `ClipRRect` a caller nests directly inside a `GlassLayer`,
  /// between it and one of its `Glass` shapes) are captured so they can be
  /// re-pushed outside the layer's own backdrop pass, where they will not
  /// move with it.
  void collect(RenderObject shape, RenderObject layer) {
    final found = <_Captured>[];

    var child = shape;
    var node = shape.parent;
    while (node != null && !identical(node, layer)) {
      final captured = _capture(node, child);
      if (captured != null) {
        found.add(captured);
      }
      child = node;
      node = node.parent;
    }

    // [found] was built walking from the shape outward, so its last entry
    // is nearest the layer -- the outermost clip, which must be pushed
    // first so it ends up outermost in the re-pushed chain. Each entry's
    // transform is resolved relative to whichever entry ends up as its
    // immediate parent once reversed (or to `layer`, for the one that ends
    // up outermost) -- never straight to `layer` regardless of position,
    // which is what let two nested clips double-apply the ancestor path
    // they share.
    final outermostFirst = found.reversed.toList(growable: false);
    _clips
      ..clear()
      ..addAll(<RetainedClip>[
        for (var i = 0; i < outermostFirst.length; i++)
          RetainedClip(
            rect: outermostFirst[i].rect,
            rrect: outermostFirst[i].rrect,
            behavior: outermostFirst[i].behavior,
            transform: outermostFirst[i].node.getTransformTo(
              i == 0 ? layer : outermostFirst[i - 1].node,
            ),
          ),
      ]);
  }

  static _Captured? _capture(RenderObject node, RenderObject child) {
    // Asks the node itself what it actually clips `child` to, rather than
    // reconstructing that decision from the node's public properties. It
    // returns `null` for `Clip.none`, so a caller who turned an ancestor's
    // clipping off does not get it silently reinstated here, and it honours
    // a custom `clipper`'s narrower bounds instead of the node's own full
    // `paintBounds`. Retaining a clip the node would not itself have
    // applied crops content -- blur bleed, deliberate overdraw -- that the
    // node deliberately left alone.
    //
    // `child` is always `node`'s direct child by construction of the walk
    // above, which is what the `RenderSliver`-typed override on
    // `RenderViewportBase` requires.
    final rect = node.describeApproximatePaintClip(child);
    if (rect == null) {
      return null;
    }

    if (node is RenderClipRect) {
      return _Captured(node: node, rect: rect, behavior: node.clipBehavior);
    }
    if (node is RenderClipRRect) {
      final direction = node.textDirection ?? TextDirection.ltr;
      return _Captured(
        node: node,
        rect: rect,
        rrect: node.borderRadius.resolve(direction).toRRect(rect),
        behavior: node.clipBehavior,
      );
    }
    if (node is RenderClipOval) {
      return _Captured(node: node, rect: rect, behavior: node.clipBehavior);
    }
    if (node is RenderClipPath) {
      return _Captured(node: node, rect: rect, behavior: node.clipBehavior);
    }
    if (node is RenderViewportBase) {
      // One gate `describeApproximatePaintClip` does not carry: a
      // viewport's own `paint` additionally skips its clip when
      // `hasVisualOverflow` is false, and that member is `@protected`, so
      // this chain cannot read it and the viewport's override does not
      // consult it either. A viewport whose contents fit exactly therefore
      // gets its clip retained here when it would not have applied one,
      // which can crop a child that paints past its layout box.
      //
      // Accepted deliberately rather than reconstructed: the two terms of
      // that decision the public API does expose -- each sliver child's
      // `SliverGeometry.hasVisualOverflow` -- omit the overscroll term
      // (`RenderViewport` also sets it from a corrected scroll offset).
      // Rebuilding the gate from those alone would under-clip exactly
      // during overscroll, which is the tearing this whole mechanism
      // exists to stop. Over-clipping an exactly-fitting viewport is the
      // safe direction of the two.
      return _Captured(node: node, rect: rect, behavior: node.clipBehavior);
    }
    return null;
  }

  /// Whether [other] describes the same clips.
  ///
  /// Reserved for a caller that wants to key a cached result (for example a
  /// built layer or filter) on whether the retained chain actually changed
  /// shape between paints, without needing to compare every field of every
  /// [RetainedClip]. Not currently called in production: `paint()` re-walks
  /// and re-pushes the chain unconditionally, since an ancestor's position
  /// relative to the layer can change (most commonly by scrolling) without
  /// anything else signalling that a re-walk is needed, which makes a
  /// skip-when-unchanged fast path unsound to add speculatively -- see
  /// `render_glass_layer.dart`'s `paint` for the fuller reasoning. Covered
  /// directly by its own tests in `retained_clip_chain_unit_test.dart` so
  /// it does not silently rot while unused.
  bool matches(RetainedClipChain other) {
    if (other._clips.length != _clips.length) {
      return false;
    }
    for (var i = 0; i < _clips.length; i++) {
      if (_clips[i].rect != other._clips[i].rect ||
          _clips[i].behavior != other._clips[i].behavior) {
        return false;
      }
    }
    return true;
  }
}

/// A clip found while walking, before its chain-relative transform (which
/// depends on neighbouring entries, decided only after the whole walk
/// completes) is known.
///
/// No `path` field: none of the node types `RetainedClipChain._capture`
/// recognizes populates one -- see [RetainedClip.path]'s own doc comment.
class _Captured {
  _Captured({
    required this.node,
    required this.rect,
    required this.behavior,
    this.rrect,
  });

  final RenderObject node;
  final Rect rect;
  final RRect? rrect;
  final Clip behavior;
}
