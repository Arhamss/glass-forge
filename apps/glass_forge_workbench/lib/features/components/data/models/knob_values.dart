import 'package:equatable/equatable.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';

/// The current setting of every knob on a playground, keyed by knob id.
class KnobValues extends Equatable {
  const KnobValues(this._values);

  factory KnobValues.initial(List<StoryKnob> knobs) =>
      KnobValues({for (final knob in knobs) knob.id: knob.initial});

  final Map<String, Object> _values;

  bool toggle(String id) => _values[id] as bool? ?? false;
  double slider(String id) => (_values[id] as num?)?.toDouble() ?? 0;
  int stepper(String id) => _values[id] as int? ?? 0;
  int choice(String id) => _values[id] as int? ?? 0;

  KnobValues set(String id, Object value) =>
      KnobValues({..._values, id: value});

  @override
  List<Object?> get props => [_values];
}
