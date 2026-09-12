/// What a rung of the tier ladder is doing right now.
///
/// [inForce] is what the user asked for, [rendering] is what the device
/// actually draws; separating them stops two rungs both claiming to be "in
/// force" when automatic resolution lands on a tier.
enum TierRungStatus { inForce, rendering, heldAt, wouldHoldAt, none }
