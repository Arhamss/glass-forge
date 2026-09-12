import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/tiers/data/models/tier_rung_status.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/cubit/tier_state.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/widgets/instrument/tier_ladder_rung.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_tier_extensions.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_note.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';

/// The five rungs plus the automatic setting, each with what it does to a
/// material and whether this device will actually give it to you.
class TierLadderGroup extends StatelessWidget {
  /// Creates the group.
  const TierLadderGroup({
    required this.state,
    required this.onTierForced,
    super.key,
  });

  /// The engine's verdict and the evidence behind it.
  final TierState state;

  /// Called with the rung to pin, or null to go back to automatic.
  final ValueChanged<GlassTier?> onTierForced;

  String _words(TierRungStatus status, GlassTier tier) => switch (status) {
    TierRungStatus.inForce => 'in force',
    TierRungStatus.rendering => 'rendering now',
    TierRungStatus.heldAt =>
      'held at ${state.heldTierFor(tier).label.toLowerCase()}',
    TierRungStatus.wouldHoldAt =>
      'would hold at ${state.heldTierFor(tier).label.toLowerCase()}',
    TierRungStatus.none => '',
  };

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Ladder',
      cells: [
        TierLadderRung(
          label: 'Automatic',
          effect:
              'Let capability, heat, frame health and the accessibility '
              'settings decide, and re-decide, on their own.',
          status: state.statusFor(null) == TierRungStatus.inForce
              ? 'in force'
              : '',
          isSelected: state.requested == null,
          isInForce: state.requested == null,
          onTap: () => onTierForced(null),
        ),
        for (final tier in GlassTier.values)
          TierLadderRung(
            label: tier.label,
            effect: tier.effect,
            status: _words(state.statusFor(tier), tier),
            isSelected: tier == state.requested,
            isInForce: tier == state.resolved.tier,
            onTap: () => onTierForced(tier),
          ),
        if (state.isPinHeld)
          InstrumentNote(
            text:
                'Pinned to '
                '${state.requested!.label.toLowerCase()}, rendering '
                '${state.resolved.tier.label.toLowerCase()}. A pin beats '
                'capability, heat and frame health. It does not beat the '
                'accessibility settings, and it cannot lift a backend '
                'where the filter throws instead of running. Opting out of '
                'either would mean opting out on behalf of someone else.',
          ),
      ],
    );
  }
}
