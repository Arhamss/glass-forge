import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/chrome/glass_detent_sheet_controller.dart';

/// The physics that makes one gesture cross from a sheet to the list inside
/// it and back, with no lifted finger.
///
/// Position and direction decide, in that order. Below the top detent the
/// sheet owns every vertical delta and the list does not move. At the top
/// detent the list owns them — until it is scrolled back to the top of its
/// own content and the finger is *still* going down, at which point the sheet
/// takes the gesture back and descends.
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
///
/// Two things it does not reach, both worth knowing before debugging one of
/// them:
///
/// * **A scrollable that names its own `physics` opts out.** `Scrollable`
///   resolves `widget.physics!.applyTo(ambient)`, which makes the caller's
///   choice the *parent* of this one — so a `ListView(physics:
///   BouncingScrollPhysics())` inside a sheet ends up with this class below
///   `BouncingScrollPhysics` — whose own `applyPhysicsToUserOffset` computes
///   a result without delegating down. The handoff then never runs, silently.
///   A scrollable inside a sheet should leave `physics` null and let the
///   sheet's `ScrollConfiguration` supply it.
/// * **Pointer scrolling is not routed.** A trackpad or wheel goes through
///   `ScrollPosition.pointerScroll`, which reaches `applyBoundaryConditions`
///   but never `applyPhysicsToUserOffset`, so a wheel over a sheet scrolls the
///   list and never moves the sheet. That is the right behaviour on a desktop
///   pointer — there is no finger to hand anything back to — and it is stated
///   here so nobody reads it as a bug.
class GlassSheetScrollPhysics extends ScrollPhysics {
  /// Creates physics that hand their vertical deltas to [controller] whenever
  /// the sheet, rather than the list, is what the finger is moving.
  ///
  /// Not a `const` constructor, unlike most of the framework's physics, and
  /// the reason is [_carry]: an instance has to remember, between the two
  /// overrides below, whether *it* was the one that took the sheet over. Two
  /// identical `const` instances would be canonicalised into one and would
  /// then share that bit.
  GlassSheetScrollPhysics({required this.controller, super.parent})
    : _carry = _SheetCarry();

  // Positional, because a named parameter cannot be a private initialising
  // formal and this one is nobody else's business.
  const GlassSheetScrollPhysics._(
    this._carry, {
    required this.controller,
    super.parent,
  });

  /// The sheet this scrollable is inside.
  final GlassDetentSheetController controller;

  /// Whether this physics is the thing currently carrying the sheet.
  ///
  /// [GlassDetentSheetController.isDragging] cannot answer that question: it
  /// is equally true when the sheet's own handle is being dragged, and a
  /// handle drag resizes the sheet, which resizes the inner list's viewport,
  /// which is a dimension change, which an idle `ScrollPosition` answers with
  /// `goBallistic(0)` — landing in [createBallisticSimulation] on the first
  /// frame of every handle drag over a scrollable child. Ending a drag this
  /// object never started is what that used to do.
  ///
  /// A mutable cell rather than a field because `ScrollPhysics` is
  /// `@immutable`, and shared by reference through [applyTo] so the whole
  /// chain agrees on one answer.
  final _SheetCarry _carry;

  @override
  GlassSheetScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      GlassSheetScrollPhysics._(
        _carry,
        controller: controller,
        parent: buildParent(ancestor),
      );

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.axis != Axis.vertical) {
      // `ScrollBehavior.getScrollPhysics` is axis-agnostic, so a horizontal
      // carousel inside the sheet — a chip row, a card strip — gets these
      // physics too. It has nothing to hand over: a sideways swipe is not a
      // gesture the sheet has any claim on.
      return super.applyPhysicsToUserOffset(position, offset);
    }

    // What governs every sign here is that [offset] is not the finger. It is
    // a scroll delta in the viewport's own sense, and `ScrollDragController`
    // has already negated the finger's `primaryDelta` once more when the
    // viewport is reversed. Unreversing it gives the finger back, positive
    // downward; the sheet's height then grows the other way again, because
    // [GlassDetentSheetController.dragBy] is positive to *raise* it.
    final reversed = axisDirectionIsReversed(position.axisDirection);
    final fingerDelta = reversed ? -offset : offset;
    final draggingDown = fingerDelta > 0;

    // Where the list runs out of content to reveal above itself. In a normal
    // viewport that is `minScrollExtent`; in a reversed one — the standard
    // chat and log layout — the same edge is `maxScrollExtent`, because
    // pulling down there scrolls *back* through the history.
    final atContentTop = reversed
        ? position.pixels >= position.maxScrollExtent
        : position.pixels <= position.minScrollExtent;

    // Rule 1 below the top detent, rule 3 at it. Both hand the delta to the
    // sheet; only the condition differs.
    final sheetOwnsIt =
        controller.value < controller.top || (draggingDown && atContentTop);

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
    _carry.value = true;
    controller.dragBy(-fingerDelta);
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
    // finger stopped is not a detent sheet.
    //
    // Gated on [_carry] and not on the controller's own `isDragging`, so that
    // the sheet's handle drags, the ordinary end of a list scroll, and every
    // other route into `goBallistic` are left alone. This ends the drag it
    // began, and only that one.
    if (_carry.value) {
      _carry.value = false;
      // [velocity] is in scroll pixels per second — positive means `pixels`
      // rising, which is the finger going up in a normal viewport and down in
      // a reversed one. The sheet counts upward as positive either way.
      final reversed = axisDirectionIsReversed(position.axisDirection);
      controller.endDrag(velocity: reversed ? -velocity : velocity);
    }
    return super.createBallisticSimulation(position, velocity);
  }
}

/// One bit of drag ownership, shared by reference across a physics chain.
///
/// Exists only because `ScrollPhysics` is `@immutable` and this one honestly
/// is not: see [GlassSheetScrollPhysics._carry].
class _SheetCarry {
  bool value = false;
}
