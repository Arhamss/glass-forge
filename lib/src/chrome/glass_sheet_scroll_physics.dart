import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/chrome/glass_detent_sheet_controller.dart';

/// The physics that makes one gesture cross from a sheet to the list inside
/// it and back, with no lifted finger.
///
/// Position and direction decide, in that order. Below the top detent the
/// sheet owns every vertical delta and the list does not move. At the top
/// detent the list owns them — until it is scrolled back to its own zero and
/// the finger is *still* going down, at which point the sheet takes the
/// gesture back and descends.
///
/// This is `NestedScrollView`'s problem shape and not its API. The framework
/// solves the same one in `DraggableScrollableSheet`, by overriding
/// `applyUserOffset` on a private `ScrollPosition`; here the sheet's position
/// lives in a [GlassDetentSheetController] rather than in a scroll position,
/// so the interception is a `ScrollPhysics` instead and the controller is the
/// thing both consumers agree about.
///
/// Installed by `GlassDetentSheet` on every scrollable inside it, through a
/// `ScrollConfiguration`. Nothing looks this up: a scrollable that wants it
/// already has it, and one outside a sheet has no sheet to hand a gesture to.
class GlassSheetScrollPhysics extends ScrollPhysics {
  /// Creates physics that hand their vertical deltas to [controller] whenever
  /// the sheet, rather than the list, is what the finger is moving.
  const GlassSheetScrollPhysics({required this.controller, super.parent});

  /// The sheet this scrollable is inside.
  final GlassDetentSheetController controller;

  @override
  GlassSheetScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      GlassSheetScrollPhysics(
        controller: controller,
        parent: buildParent(ancestor),
      );

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // The two conventions are opposed, and that is where every sign here
    // comes from. A scroll [offset] is positive when the content moves down,
    // which is a finger moving down; the sheet's height grows upward and
    // [GlassDetentSheetController.dragBy] is positive to raise it. So a delta
    // routed to the sheet is negated, and a positive [offset] is the finger
    // going *down*, which lowers the sheet.
    final draggingDown = offset > 0;
    final atScrollZero = position.pixels <= position.minScrollExtent;
    // Rule 1 below the top detent, rule 3 at it. Both hand the delta to the
    // sheet; only the condition differs.
    final sheetOwnsIt =
        controller.value < controller.top || (draggingDown && atScrollZero);

    if (!sheetOwnsIt) {
      // Rule 2: the list scrolls, and the sheet is not told about it.
      return super.applyPhysicsToUserOffset(position, offset);
    }

    if (!controller.isDragging) {
      // The sheet is being carried by a finger it never saw a down event
      // for, so it is told here instead: this stops any snap still in flight
      // and zeroes the velocity the drag is about to replace. Idempotent, so
      // it is safe to ask on every delta.
      controller.beginDrag();
    }
    controller.dragBy(-offset);
    // Nothing is left over for the list. A delta that raises the sheet past
    // its top detent is clamped away by `dragBy` rather than spilling into
    // the scrollable — the same thing `DraggableScrollableSheet` does, and
    // the reason a real finger's deltas are small enough not to notice.
    return 0;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // The end of the gesture, for the sheet as well as for the list: a
    // `ScrollPhysics` has no other hook for it, and a sheet left wherever the
    // finger stopped is not a detent sheet. The velocity needs no sign
    // change — `ScrollDragController` already negates the pointer's, so a
    // finger flung upward arrives here positive, which is also the sheet's
    // sense of upward.
    //
    // Guarded on [GlassDetentSheetController.isDragging] so that the ordinary
    // end of a list scroll, and every other route into `goBallistic`, leaves
    // the sheet alone: only a gesture this physics actually routed to the
    // sheet set that flag.
    if (controller.isDragging) {
      controller.endDrag(velocity: velocity);
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
