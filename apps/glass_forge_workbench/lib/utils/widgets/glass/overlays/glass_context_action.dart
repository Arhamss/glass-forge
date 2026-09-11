import 'package:flutter/foundation.dart';

/// One row of a `GlassContextMenu`.
@immutable
class GlassContextAction {
  const GlassContextAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final String label;

  /// An asset path.
  final String icon;

  /// Runs after the menu has been closed.
  final VoidCallback onSelected;

  /// Draws the row in the danger colour, for actions that delete or cannot
  /// be undone.
  final bool destructive;
}
