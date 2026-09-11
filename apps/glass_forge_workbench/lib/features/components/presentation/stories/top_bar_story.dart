import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_circle_button.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_top_bar.dart';

ComponentStory topBarStory() => ComponentStory(
  knobs: [
    ChoiceKnob(
      id: 'leading',
      label: Localization.knobLeading,
      options: [
        Localization.optionNone,
        Localization.optionBack,
        Localization.optionProfile,
      ],
      initialIndex: 1,
    ),
    ChoiceKnob(
      id: 'trailing',
      label: Localization.knobTrailing,
      options: [
        Localization.optionNone,
        Localization.optionShare,
        Localization.optionMore,
      ],
      initialIndex: 2,
    ),
    ToggleKnob(id: 'badge', label: Localization.knobBadge),
  ],
  builder: (context, values) {
    final l10n = context.l10n;
    final leading = switch (values.choice('leading')) {
      1 => GlassCircleButton(
        icon: AssetPaths.caretLeft,
        semanticLabel: l10n.back,
        onPressed: () {},
      ),
      2 => GlassCircleButton(
        icon: AssetPaths.user,
        semanticLabel: l10n.demoProfile,
        onPressed: () {},
      ),
      _ => null,
    };
    final trailing = switch (values.choice('trailing')) {
      1 => GlassCircleButton(
        icon: AssetPaths.shareNetwork,
        semanticLabel: l10n.optionShare,
        badge: values.toggle('badge'),
        onPressed: () {},
      ),
      2 => GlassCircleButton(
        icon: AssetPaths.dotsThree,
        semanticLabel: l10n.optionMore,
        badge: values.toggle('badge'),
        onPressed: () {},
      ),
      _ => null,
    };
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: GlassTopBar(
        title: l10n.demoTitle,
        leading: leading,
        trailing: trailing,
      ),
    );
  },
  code: (values) =>
      '''
GlassTopBar(
  title: 'Trips',
  leading: GlassCircleButton(
    icon: AssetPaths.caretLeft,
    semanticLabel: 'Back',
    onPressed: () => context.pop(),
  ),
  trailing: GlassCircleButton(
    icon: AssetPaths.dotsThree,
    semanticLabel: 'More',
    badge: ${values.toggle('badge')},
    onPressed: openMenu,
  ),
)''',
);
