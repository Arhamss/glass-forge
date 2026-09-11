import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/scene/blend_group_link.dart';

/// Shapes inside this group merge into one another.
///
/// Scoped to its own layer: a nested layer's shapes must never register into
/// an outer group, or they would blend across a boundary the caller drew.
class GlassBlendGroup extends StatefulWidget {
  /// Creates a blend group.
  const GlassBlendGroup({required this.child, this.blend = 20.0, super.key});

  /// The subtree whose glass merges.
  final Widget child;

  /// The widest gap between two members that still merges them, in
  /// logical pixels.
  ///
  /// Members closer than this join through a smooth neck; further apart,
  /// they stay separate shapes. Overlapping members always merge, and the
  /// larger this is, the softer the join.
  final double blend;

  @override
  State<GlassBlendGroup> createState() => _GlassBlendGroupState();
}

class _GlassBlendGroupState extends State<GlassBlendGroup> {
  late final BlendGroupLink _link = BlendGroupLink(blend: widget.blend);

  @override
  void didUpdateWidget(GlassBlendGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Updated in place, rather than replacing the link: every still-attached
    // `RenderGlassShape` already listens to this exact instance, and it
    // notifies them of the new blend width itself.
    _link.blend = widget.blend;
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBlendGroupScope(link: _link, child: widget.child);
  }
}

/// Exposes a [BlendGroupLink] to descendants.
class GlassBlendGroupScope extends InheritedWidget {
  /// Creates a scope.
  const GlassBlendGroupScope({
    required this.link,
    required super.child,
    super.key,
  });

  /// The group descendants join.
  final BlendGroupLink link;

  /// The nearest enclosing group, if any.
  static GlassBlendGroupScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassBlendGroupScope>();
  }

  @override
  bool updateShouldNotify(GlassBlendGroupScope oldWidget) =>
      oldWidget.link != link;
}
