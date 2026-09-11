import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/buttons/glass_button.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_bottom_sheet.dart';

ComponentStory bottomSheetStory() => ComponentStory(
  knobs: const [],
  builder: (context, values) {
    final l10n = context.l10n;
    return GlassButton.secondary(
      label: l10n.demoOpenSheet,
      onPressed: () => showGlassSheet<void>(
        context,
        builder: (sheetContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.demoSheetTitle, style: sheetContext.title),
            const SizedBox(height: AppSpacing.s8),
            Text(
              l10n.demoSheetBody,
              style: sheetContext.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s24),
            GlassButton.primary(
              label: l10n.demoContinue,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  },
  code: (values) => '''
showGlassSheet<void>(
  context,
  builder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('A sheet of glass', style: context.title),
      GlassButton.primary(label: 'Continue', onPressed: () => context.pop()),
    ],
  ),
);''',
);
