import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/cards/glass_media_card.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_action.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_menu.dart';

ComponentStory contextMenuStory() => ComponentStory(
  knobs: [
    ToggleKnob(
      id: 'destructive',
      label: Localization.knobDestructive,
      initialValue: true,
    ),
  ],
  builder: (context, values) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s48,
      ),
      child: GlassContextMenu(
        actions: [
          GlassContextAction(
            label: l10n.savePlace,
            icon: AssetPaths.bookmarkSimple,
            onSelected: () {},
          ),
          GlassContextAction(
            label: l10n.copyName,
            icon: AssetPaths.copy,
            onSelected: () {},
          ),
          if (values.toggle('destructive'))
            GlassContextAction(
              label: l10n.demoDelete,
              icon: AssetPaths.trash,
              destructive: true,
              onSelected: () {},
            ),
        ],
        child: GlassMediaCard(
          image: AssetPaths.photoCoastalTown,
          title: 'Riomaggiore',
          subtitle: l10n.demoLongPress,
        ),
      ),
    );
  },
  code: (values) =>
      '''
GlassContextMenu(
  actions: [
    GlassContextAction(label: 'Save', icon: AssetPaths.bookmarkSimple, onSelected: save),${values.toggle('destructive') ? "\n    GlassContextAction(label: 'Delete', icon: AssetPaths.trash, destructive: true, onSelected: delete)," : ''}
  ],
  child: card,
)''',
);
