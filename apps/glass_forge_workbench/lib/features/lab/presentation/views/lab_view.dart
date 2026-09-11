import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/lab/presentation/widgets/lab_tool_row.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/enums/lab_tool.dart';
import 'package:glass_forge_workbench/utils/widgets/layout/shell_insets.dart';

/// The index of the engineering tools. Each opens full-screen, above the tab
/// bar, so the specimen it measures is the only glass on screen.
class LabView extends StatelessWidget {
  const LabView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.gutter,
                AppSpacing.s24,
                AppSpacing.gutter,
                AppSpacing.s24,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.labTitle, style: context.display),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      l10n.labSubtitle,
                      style: context.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.gutter,
            ),
            sliver: SliverToBoxAdapter(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.r24),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    for (final tool in LabTool.values) ...[
                      if (tool != LabTool.values.first)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          indent: 68,
                          color: AppColors.hairline,
                        ),
                      LabToolRow(
                        tool: tool,
                        onTap: () => context.pushNamed(tool.routeName),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: ShellInsets.bottomClearance(context)),
          ),
        ],
      ),
    );
  }
}
