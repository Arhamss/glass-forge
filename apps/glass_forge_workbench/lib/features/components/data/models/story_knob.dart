/// One control on a playground's Variants pane.
///
/// Sealed, so a pane that renders knobs is checked for every kind — and so
/// all of them live in this one file: Dart only allows a sealed type's
/// subtypes inside its own library.
sealed class StoryKnob {
  const StoryKnob({required this.id, required this.label});

  /// The key its value is stored under in `KnobValues`.
  final String id;
  final String label;

  Object get initial;
}

final class ToggleKnob extends StoryKnob {
  const ToggleKnob({
    required super.id,
    required super.label,
    this.initialValue = false,
  });

  final bool initialValue;

  @override
  Object get initial => initialValue;
}

final class SliderKnob extends StoryKnob {
  const SliderKnob({
    required super.id,
    required super.label,
    required this.min,
    required this.max,
    required this.initialValue,
    this.unit = '',
    this.fractionDigits = 1,
  });

  final double min;
  final double max;
  final double initialValue;

  /// Shown after the value, e.g. `px` or `×`. Empty for a plain ratio.
  final String unit;
  final int fractionDigits;

  String format(double value) {
    final number = value.toStringAsFixed(fractionDigits);
    return unit.isEmpty ? number : '$number $unit';
  }

  @override
  Object get initial => initialValue;
}

final class StepperKnob extends StoryKnob {
  const StepperKnob({
    required super.id,
    required super.label,
    required this.min,
    required this.max,
    required this.initialValue,
  });

  final int min;
  final int max;
  final int initialValue;

  @override
  Object get initial => initialValue;
}

final class ChoiceKnob extends StoryKnob {
  const ChoiceKnob({
    required super.id,
    required super.label,
    required this.options,
    this.initialIndex = 0,
  });

  final List<String> options;
  final int initialIndex;

  @override
  Object get initial => initialIndex;
}
