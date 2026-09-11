import 'package:flutter/widgets.dart';
import 'package:glass_forge_workbench/features/components/data/models/knob_values.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';

/// Everything a playground needs to show one component: the knobs it offers,
/// the component built from their values, and the code that builds it.
class ComponentStory {
  const ComponentStory({
    required this.knobs,
    required this.builder,
    required this.code,
  });

  final List<StoryKnob> knobs;
  final Widget Function(BuildContext context, KnobValues values) builder;
  final String Function(KnobValues values) code;
}
