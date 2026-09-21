import 'package:flutter/widgets.dart';

/// One tunable parameter of a [CatalogueEntry].
///
/// Carries its own range or options so the entry page can render a control
/// for it without the entry describing one — the declaration says what the
/// parameter *is*, not what widget adjusts it.
@immutable
class Knob<T> {
  /// Creates a knob.
  ///
  /// [options] is copied into an unmodifiable list, so holding a knob's
  /// [options] never grants a way to change it in place — the only way to
  /// change a knob is [withValue], which produces a new one.
  Knob({
    required this.name,
    required this.value,
    List<T> options = const <Never>[],
    this.min,
    this.max,
  }) : options = List.unmodifiable(options);

  /// The parameter's name, as it appears in the API.
  final String name;

  /// Its current value.
  final T value;

  /// The choices, for a knob adjusted by a segmented control.
  final List<T> options;

  /// The low end, for a knob adjusted by a slider.
  final double? min;

  /// The high end, for a knob adjusted by a slider.
  final double? max;

  /// This knob with [next] in place of [value].
  Knob<T> withValue(T next) => Knob<T>(
    name: name,
    value: next,
    options: options,
    min: min,
    max: max,
  );
}

/// One capability, shown live with the code that produces it.
///
/// [build] and [code] are both functions of [knobs], which is the whole
/// point: a snippet that says something other than what is rendered beside
/// it is worse than no snippet, because the reader trusts it. Deriving both
/// from one list means there is nothing to keep in sync.
@immutable
class CatalogueEntry {
  /// Creates an entry.
  ///
  /// [knobs] is copied into an unmodifiable list, so holding an entry's
  /// [knobs] never grants a way to change it in place — the only way to
  /// change a knob is [withKnob], which produces a new entry.
  CatalogueEntry({
    required this.api,
    required this.purpose,
    required this.group,
    required List<Knob<Object?>> knobs,
    required this.build,
    required this.code,
    this.seeAlso = const <String>[],
  }) : knobs = List.unmodifiable(knobs);

  /// The API name. This is the string a reader would search for.
  final String api;

  /// One line on what it is for.
  final String purpose;

  /// Which of the seven groups this belongs to.
  final String group;

  /// The parameters this entry lets the reader move.
  final List<Knob<Object?>> knobs;

  /// Builds the live thing from [knobs].
  final Widget Function(List<Knob<Object?>> knobs) build;

  /// Renders the Dart that produces [build]'s result, from the same [knobs].
  final String Function(List<Knob<Object?>> knobs) code;

  /// Other entries worth reading next, by [api].
  final List<String> seeAlso;

  /// This entry with knob [index] set to [value].
  CatalogueEntry withKnob(int index, Object? value) {
    return CatalogueEntry(
      api: api,
      purpose: purpose,
      group: group,
      knobs: <Knob<Object?>>[
        for (var i = 0; i < knobs.length; i++)
          if (i == index) knobs[i].withValue(value) else knobs[i],
      ],
      build: build,
      code: code,
      seeAlso: seeAlso,
    );
  }
}
