import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
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

  String _statusFor(GlassTier tier) {
    final isInForce = tier == state.resolved.tier;
    final isPinned = tier == state.requested;
    final outcome = state.outcomeFor(tier);
    if (isPinned && outcome != tier) {
      return 'held at ${outcome.label.toLowerCase()}';
    }
    if (isInForce) {
      return 'in force';
    }
    if (outcome != tier) {
      return 'would hold at ${outcome.label.toLowerCase()}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Ladder',
      cells: [
        TierLadderRung(
          label: 'Automatic',
          effect: 'Let capability, heat, frame health and the accessibility '
              'settings decide, and re-decide, on their own.',
          status: state.requested == null ? 'in force' : '',
          isSelected: state.requested == null,
          isInForce: state.requested == null,
          onTap: () => onTierForced(null),
        ),
        for (final tier in GlassTier.values)
          TierLadderRung(
            label: tier.label,
            effect: tier.effect,
            status: _statusFor(tier),
            isSelected: tier == state.requested,
            isInForce: tier == state.resolved.tier,
            onTap: () => onTierForced(tier),
          ),
        if (state.isPinHeld)
          InstrumentNote(
            text: 'Pinned to '
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
