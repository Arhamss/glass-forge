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
  /// Not a `const` constructor, unlike most of the framework's physics —
  /// which is a deliberate departure from the signature this class was
  /// specified with, so it is written down here rather than left to be found.
  /// The reason is [_carry]: an instance has to remember, between the two
  /// overrides below, *which scrollable* took the sheet over. Two identical
  /// `const` instances would be canonicalised into one and would then share
  /// that memory, which is the one thing it must not do.
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

  /// Which scrollable, if any, is currently carrying the sheet.
  ///
  /// The question [createBallisticSimulation] has to answer is not "is the
  /// sheet being dragged" but "is the sheet being dragged *by the scrollable
  /// now asking*", and it takes a scrollable's identity to answer it.
  /// [GlassDetentSheetController.isDragging] is too coarse — it is equally
  /// true of a drag on the sheet's own handle — and so is a plain flag, which
  /// is equally true of a drag on a *sibling* scrollable.
  ///
  /// Both of those matter for the same reason. Carrying the sheet resizes it
  /// every frame, which resizes the viewport of every scrollable inside it,
  /// which is a dimension change. The scrollable under the finger is immune,
  /// because its `DragScrollActivity.applyNewDimensions` is the inherited
  /// no-op — but any *other* one is idle, and
  /// `IdleScrollActivity.applyNewDimensions` answers a dimension change with
  /// `goBallistic(0)`. So a handle drag, or a drag on a neighbouring list,
  /// arrives here on the next frame asking to end a drag it has nothing to do
  /// with, under a finger that is still down.
  ///
  /// `ScrollPosition implements ScrollMetrics`, so the object handed to
  /// [applyPhysicsToUserOffset] is the same object handed to
  /// [createBallisticSimulation], and `identical` settles it.
  ///
  /// A mutable cell rather than a field because `ScrollPhysics` is
  /// `@immutable`. One cell serves every scrollable in one sheet, which is
  /// why it has to name one: `GlassDetentSheet` builds a single instance of
  /// these physics and its `ScrollConfiguration` hands that same instance to
  /// every descendant — `_WrappedScrollBehavior.getScrollPhysics` returns the
  /// stored object directly, and a scrollable that does not override
  /// `physics` never calls [applyTo] at all. The cell is threaded through
  /// [applyTo] anyway, for the case that does.
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
    _carry.owner = position;
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
    // `goBallistic` is a much busier road than "a drag just ended", though —
    // every idle scrollable in the sheet drives down it on every frame the
    // sheet resizes. So this ends the drag it began, identified by the
    // scrollable that began it, and nothing else. See [_carry].
    if (position.axis != Axis.vertical) {
      // Unreachable while [applyPhysicsToUserOffset] refuses to take a
      // horizontal scrollable's deltas, and stated anyway: the two gates say
      // the same thing, and a later edit that loosens one should have to
      // notice the other.
      return super.createBallisticSimulation(position, velocity);
    }
    if (identical(position, _carry.owner)) {
      _carry.owner = null;
      // [velocity] is in scroll pixels per second — positive means `pixels`
      // rising, which is the finger going up in a normal viewport and down in
      // a reversed one. The sheet counts upward as positive either way.
      final reversed = axisDirectionIsReversed(position.axisDirection);
      controller.endDrag(velocity: reversed ? -velocity : velocity);
    }
    return super.createBallisticSimulation(position, velocity);
  }
}

/// Which scrollable is carrying the sheet, if one is.
///
/// Exists only because `ScrollPhysics` is `@immutable` and this one honestly
/// is not: see [GlassSheetScrollPhysics._carry].
class _SheetCarry {
  ScrollMetrics? owner;
}
