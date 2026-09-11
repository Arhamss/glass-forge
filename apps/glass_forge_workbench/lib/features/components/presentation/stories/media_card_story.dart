import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/cards/glass_media_card.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_circle_button.dart';

ComponentStory mediaCardStory() => ComponentStory(
  knobs: [
    ChoiceKnob(
      id: 'photo',
      label: Localization.knobPhoto,
      options: [
        Localization.optionLake,
        Localization.optionCity,
        Localization.optionCliffs,
      ],
    ),
    ToggleKnob(id: 'chip', label: Localization.knobChip, initialValue: true),
    ToggleKnob(
      id: 'action',
      label: Localization.knobAction,
      initialValue: true,
    ),
    SliderKnob(
      id: 'aspect',
      label: Localization.knobAspect,
      min: 0.7,
      max: 1.4,
      initialValue: 0.9,
      fractionDigits: 2,
    ),
  ],
  builder: (context, values) {
    final photo = switch (values.choice('photo')) {
      1 => AssetPaths.photoTokyoRain,
      2 => AssetPaths.photoSeaCliffs,
      _ => AssetPaths.photoAlpineLake,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s40,
      ),
      child: GlassMediaCard(
        image: photo,
        title: 'Lago di Braies',
        subtitle: 'Dolomites · 12.4 km',
        aspectRatio: values.slider('aspect'),
        chip: values.toggle('chip') ? '14°' : null,
        trailing: values.toggle('action')
            ? GlassCircleButton(
                icon: AssetPaths.bookmarkSimple,
                semanticLabel: context.l10n.savePlace,
                onPressed: () {},
              )
            : null,
        onTap: () {},
      ),
    );
  },
  code: (values) =>
      '''
GlassMediaCard(
  image: 'assets/images/lake.jpg',
  title: 'Lago di Braies',
  subtitle: 'Dolomites · 12.4 km',
  aspectRatio: ${values.slider('aspect').toStringAsFixed(2)},${values.toggle('chip') ? "\n  chip: '14°'," : ''}${values.toggle('action') ? "\n  trailing: GlassCircleButton(icon: AssetPaths.bookmarkSimple, semanticLabel: 'Save', onPressed: save)," : ''}
  onTap: openPlace,
)''',
);
