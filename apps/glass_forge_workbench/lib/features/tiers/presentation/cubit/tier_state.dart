import 'package:equatable/equatable.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/tiers/data/models/tier_rung_status.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';

/// State for the tiers screen.
///
/// Holds the engine's verdict whole rather than picking fields off it. The
/// point of the screen is that the verdict arrived with its evidence
/// attached, and a state class that kept only the tier would throw that
/// away exactly the way every other package does.
class TierState extends Equatable {
  /// Creates a state.
  const TierState({
    required this.resolved,
    this.backdrop = GlassBackdrop.gradientMesh,
  });

  /// The engine's current answer, and every input behind it.
  final ResolvedTier resolved;

  /// The backdrop the specimen is judged over.
  final GlassBackdrop backdrop;

  /// The tier a caller has pinned, if any.
  GlassTier? get requested => resolved.requested;

  /// Whether a pin was made and then not honoured.
  bool get isPinHeld =>
      resolved.requested != null && resolved.requested != resolved.tier;

  /// What the engine would land on if [tier] were pinned right now.
  ///
  /// Runs the package's own resolver over the same four signals rather
  /// than re-deriving the rules, so a rung that says it is unreachable is
  /// unreachable for the same reason the engine would give.
  GlassTier outcomeFor(GlassTier tier) => resolveTier(
    capabilities: resolved.capabilities,
    thermal: resolved.thermal,
    frameHealth: resolved.frameHealth,
    accessibility: resolved.accessibility,
    requested: tier,
  ).tier;

  /// Returns a copy with the given fields replaced.
  /// What [tier]'s rung is doing, or the automatic rung's when null.
  ///
  /// Only one rung can be [TierRungStatus.inForce] — the pin, or automatic
  /// when nothing is pinned — and only one can be rendering.
  TierRungStatus statusFor(GlassTier? tier) {
    if (tier == null) {
      return requested == null ? TierRungStatus.inForce : TierRungStatus.none;
    }
    final outcome = outcomeFor(tier);
    if (tier == requested) {
      return outcome == tier ? TierRungStatus.inForce : TierRungStatus.heldAt;
    }
    if (tier == resolved.tier) return TierRungStatus.rendering;
    if (outcome != tier) return TierRungStatus.wouldHoldAt;
    return TierRungStatus.none;
  }

  /// The tier a rung would hold at, for the statuses that name one.
  GlassTier heldTierFor(GlassTier tier) => outcomeFor(tier);

  TierState copyWith({ResolvedTier? resolved, GlassBackdrop? backdrop}) {
    return TierState(
      resolved: resolved ?? this.resolved,
      backdrop: backdrop ?? this.backdrop,
    );
  }

  @override
  List<Object?> get props => [resolved, backdrop];
}
