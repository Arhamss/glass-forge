import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/demos/slider_demo.dart';

ComponentStory sliderStory() => ComponentStory(
  knobs: const [],
  builder: (context, values) => const Padding(
    padding: EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.s32),
    child: SliderDemo(),
  ),
  code: (values) => r'''
GlassSlider(
  value: brightness,
  semanticLabel: 'Brightness',
  semanticValue: '${(brightness * 100).round()}%',
  onChanged: (value) => setState(() => brightness = value),
)''',
);
