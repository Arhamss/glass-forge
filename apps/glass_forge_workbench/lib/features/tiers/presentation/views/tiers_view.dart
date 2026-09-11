import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/cubit/tier_cubit.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/cubit/tier_state.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/widgets/instrument/tier_diagnostic_group.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/widgets/instrument/tier_evidence_group.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/widgets/instrument/tier_ladder_group.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/widgets/instrument/tier_material_group.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/widgets/instrument/tier_profile_group.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/widgets/tier_stage.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_tier_extensions.dart';

/// The tier engine, made readable.
///
/// Anyone can print which tier a device landed on. The four signals that
/// produced it, the ceiling each one imposed, and what a pinned tier can
/// and cannot override are the parts that let a developer act on it, so
/// they are what this screen spends its room on.
class TiersView extends StatelessWidget {
  /// Creates the view.
  const TiersView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TierCubit()..init(),
      child: Scaffold(
        backgroundColor: AppColors.stageGround,
        body: Column(
          children: [
            Expanded(
              flex: 55,
              child: BlocBuilder<TierCubit, TierState>(
                buildWhen: (previous, current) =>
                    previous.resolved.tier != current.resolved.tier ||
                    previous.resolved.requested != current.resolved.requested ||
                    previous.backdrop != current.backdrop,
                builder: (context, state) {
                  return GlassTierScope(
                    engine: context.read<TierCubit>().engine,
                    child: TierStage(
                      backdrop: state.backdrop,
                      tierName: state.resolved.tier.label.toLowerCase(),
                      isForced: state.requested != null,
                      onBackdropChanged: context.read<TierCubit>().setBackdrop,
                    ),
                  );
                },
              ),
            ),
            Expanded(
              flex: 45,
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BlocBuilder<TierCubit, TierState>(
                      buildWhen: (previous, current) =>
                          previous.resolved != current.resolved,
                      builder: (context, state) => TierLadderGroup(
                        state: state,
                        onTierForced: context.read<TierCubit>().forceTier,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<TierCubit, TierState>(
                      buildWhen: (previous, current) =>
                          previous.resolved != current.resolved,
                      builder: (context, state) =>
                          TierEvidenceGroup(resolved: state.resolved),
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<TierCubit, TierState>(
                      buildWhen: (previous, current) =>
                          previous.resolved.profile != current.resolved.profile,
                      builder: (context, state) =>
                          TierProfileGroup(profile: state.resolved.profile),
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<TierCubit, TierState>(
                      buildWhen: (previous, current) =>
                          previous.resolved.profile != current.resolved.profile,
                      builder: (context, state) =>
                          TierMaterialGroup(resolved: state.resolved),
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<TierCubit, TierState>(
                      buildWhen: (previous, current) =>
                          previous.resolved != current.resolved,
                      builder: (context, state) => TierDiagnosticGroup(
                        description: state.resolved.describe(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
