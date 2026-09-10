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
  final Path? path;

  /// How the ancestor clipped.
  final Clip behavior;

  /// Maps a point in the clipping node's local space into the layer's local
  /// space, matching [RenderObject.getTransformTo]'s convention.
  final Matrix4 transform;
}

/// The ancestor clips that must survive between a glass layer and its
/// content, re-pushed outside the layer's own moving offset.
///
/// A glass layer's contents move relative to any scrollable it sits inside.
/// If the viewport's clip is captured *inside* the moving offset layer, it
/// moves with the content and stops clipping -- which is how glass ends up
/// drawing outside its viewport, tearing on overscroll, or vanishing at the
/// scroll bounds.
///
/// Re-pushing the common prefix of ancestor clips outside the moving layer
/// keeps the viewport still while the material moves through it, which is
/// the physically correct arrangement and the one Apple's own containers
/// use: scrolling moves material through a viewport, not the viewport
/// through the material.
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
    final found = <RetainedClip>[];

    var node = shape.parent;
    while (node != null && !identical(node, layer)) {
      final captured = _capture(node, layer);
      if (captured != null) {
        found.add(captured);
      }
      node = node.parent;
    }

    // [found] was built walking from the shape outward, so its last entry
    // is nearest the layer -- the outermost clip, which must be pushed
    // first so it ends up outermost in the re-pushed chain.
    _clips
      ..clear()
      ..addAll(found.reversed);
  }

  static RetainedClip? _capture(RenderObject node, RenderObject layer) {
    final transform = node.getTransformTo(layer);

    if (node is RenderClipRect) {
      return RetainedClip(
        rect: node.paintBounds,
        behavior: node.clipBehavior,
        transform: transform,
      );
    }
    if (node is RenderClipRRect) {
      final direction = node.textDirection ?? TextDirection.ltr;
      return RetainedClip(
        rect: node.paintBounds,
        rrect: node.borderRadius.resolve(direction).toRRect(node.paintBounds),
        behavior: node.clipBehavior,
        transform: transform,
      );
    }
    if (node is RenderClipOval) {
      return RetainedClip(
        rect: node.paintBounds,
        behavior: node.clipBehavior,
        transform: transform,
      );
    }
    if (node is RenderClipPath) {
      return RetainedClip(
        rect: node.paintBounds,
        behavior: node.clipBehavior,
        transform: transform,
      );
    }
    if (node is RenderViewportBase) {
      // `hasVisualOverflow`, which paint() also gates on, is @protected and
      // unreachable from here; clipBehavior is the only signal available
      // externally. Retaining a clip the viewport would have skipped (no
      // overflow, but clipBehavior still hardEdge) is harmless -- nothing
      // painted past its own bounds for that clip to cut off.
      return RetainedClip(
        rect: node.paintBounds,
        behavior: node.clipBehavior,
        transform: transform,
      );
    }
    return null;
  }

  /// Whether [other] describes the same clips, so a cached result keyed on
  /// this chain can still be reused.
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
