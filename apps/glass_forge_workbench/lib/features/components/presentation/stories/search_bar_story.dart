import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_search_bar.dart';

ComponentStory searchBarStory() => ComponentStory(
  knobs: const [],
  builder: (context, values) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.gutter,
    ),
    child: GlassSearchBar(
      hint: context.l10n.showcaseSearchHint,
      clearLabel: context.l10n.clearSearch,
      onChanged: (_) {},
    ),
  ),
  code: (values) => '''
GlassSearchBar(
  hint: 'Search places',
  clearLabel: 'Clear search',
  value: query,
  onChanged: (value) => setState(() => query = value),
)''',
);
