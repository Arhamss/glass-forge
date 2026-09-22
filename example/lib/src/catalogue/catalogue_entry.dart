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
  ///
  /// [labelOf] names one option for whatever control adjusts this knob; see
  /// [labelFor] for when a knob has to supply one. It is typed over
  /// `Object?` rather than over [T] deliberately: every knob is held as a
  /// `Knob<Object?>` outside the entry that declares it, and a
  /// `String Function(T)` read back through that covariant view would be
  /// callable only by luck.
  Knob({
    required this.name,
    required this.value,
    List<T> options = const <Never>[],
    this.labelOf,
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

  /// What this knob calls each of its [options], if the values cannot say
  /// so themselves. See [labelFor], which is what callers should use.
  final String Function(Object? option)? labelOf;

  /// The text a segmented control puts in [option]'s segment.
  ///
  /// Without a `labelOf`, an enum constant's own name — most of this
  /// catalogue's segmented knobs choose between enum constants, and
  /// `GlassVariant.regular` reads worse on a 40pt pill than `regular`
  /// does — or the value's [Object.toString] for anything else.
  ///
  /// A knob whose options are records **must** pass one. A record's
  /// synthesised `toString()` is a debug dump of every field, which on a
  /// 40pt pill is a hundred characters of identical prefix in every
  /// segment: no API named, and no visible difference between positions.
  /// The label belongs to the knob because only the entry that declares
  /// the option type knows which of its fields is the symbol a reader
  /// would go on to search for.
  String labelFor(Object? option) =>
      labelOf?.call(option) ?? (option is Enum ? option.name : '$option');

  /// This knob with [next] in place of [value].
  Knob<T> withValue(T next) => Knob<T>(
    name: name,
    value: next,
    options: options,
    labelOf: labelOf,
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
