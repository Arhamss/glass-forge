import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/feedback/glass_toast_host.dart';

// The toast on screen, if any. There is only ever one: a new toast replaces
// it outright rather than queueing behind it.
OverlayEntry? _current;

/// Drops a short glass message in from the top of the screen, above every
/// route, and announces it to assistive technology.
///
/// It leaves by itself after a moment, or sooner when swiped up.
void showGlassToast(
  BuildContext context, {
  required String message,
  String? icon,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _remove(_current);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => GlassToastHost(
      message: message,
      icon: icon,
      onDismissed: () => _remove(entry),
    ),
  );
  _current = entry;
  overlay.insert(entry);
  unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    ),
  );
}

// Only the entry still on screen is removed. One already replaced by a newer
// toast was removed then, and an overlay entry throws if removed twice.
void _remove(OverlayEntry? entry) {
  if (entry == null || !identical(entry, _current)) return;
  _current = null;
  entry
    ..remove()
    ..dispose();
}
