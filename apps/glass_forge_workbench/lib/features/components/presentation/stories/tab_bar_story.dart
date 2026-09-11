import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/demos/tab_bar_demo.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';

ComponentStory tabBarStory() => ComponentStory(
  knobs: [
    StepperKnob(
      id: 'tabs',
      label: Localization.knobTabs,
      min: 2,
      max: 5,
      initialValue: 4,
    ),
    ToggleKnob(
      id: 'labels',
      label: Localization.knobLabels,
      initialValue: true,
    ),
    ToggleKnob(id: 'badge', label: Localization.knobBadge),
    SliderKnob(
      id: 'squash',
      label: Localization.knobSquash,
      min: 0,
      max: 1,
      initialValue: 0.8,
      unit: '×',
      fractionDigits: 2,
    ),
    SliderKnob(
      id: 'spring',
      label: Localization.knobSpring,
      min: 0.2,
      max: 0.9,
      initialValue: 0.42,
      unit: 's',
      fractionDigits: 2,
    ),
  ],
  builder: (context, values) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.gutter,
    ),
    child: TabBarDemo(
      count: values.stepper('tabs'),
      showLabels: values.toggle('labels'),
      badge: values.toggle('badge'),
      squash: values.slider('squash'),
      springSeconds: values.slider('spring'),
    ),
  ),
  code: (values) =>
      '''
GlassTabBar(
  currentIndex: index,
  onChanged: (i) => setState(() => index = i),
  showLabels: ${values.toggle('labels')},
  squash: ${values.slider('squash').toStringAsFixed(2)},
  selectorDuration: const Duration(milliseconds: ${(values.slider('spring') * 1000).round()}),
  items: const [
    GlassTabBarItem(label: 'Home', icon: AssetPaths.house, activeIcon: AssetPaths.houseFill),
    // ${values.stepper('tabs')} tabs in all
  ],
)''',
);
