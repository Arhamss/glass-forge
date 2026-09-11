import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_circle_button.dart';

ComponentStory circleButtonStory() => ComponentStory(
  knobs: [
    ChoiceKnob(
      id: 'icon',
      label: Localization.knobIcon,
      options: [
        Localization.optionHeart,
        Localization.optionBell,
        Localization.optionShare,
        Localization.optionPlus,
      ],
    ),
    ToggleKnob(id: 'badge', label: Localization.knobBadge),
  ],
  builder: (context, values) {
    final (icon, label) = switch (values.choice('icon')) {
      1 => (AssetPaths.bell, context.l10n.optionBell),
      2 => (AssetPaths.shareNetwork, context.l10n.optionShare),
      3 => (AssetPaths.plus, context.l10n.optionPlus),
      _ => (AssetPaths.heart, context.l10n.optionHeart),
    };
    return Transform.scale(
      scale: 1.6,
      child: GlassCircleButton(
        icon: icon,
        semanticLabel: label,
        badge: values.toggle('badge'),
        onPressed: () {},
      ),
    );
  },
  code: (values) =>
      '''
GlassCircleButton(
  icon: AssetPaths.heart,
  semanticLabel: 'Like',
  badge: ${values.toggle('badge')},
  onPressed: like,
)''',
);
