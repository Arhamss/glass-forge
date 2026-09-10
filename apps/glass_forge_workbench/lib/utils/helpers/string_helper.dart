extension StringHelpers on String {
  /// Capitalises the first letter and lower-cases the rest.
  /// Note: this lower-cases the remainder, so acronyms like "NASA"
  /// become "Nasa". Avoid on strings whose casing must be preserved.
  String get toLetterCase =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';

  /// Title-cases each space-separated word via [toLetterCase].
  /// Note: inherits [toLetterCase]'s behaviour of lower-casing the
  /// remainder of each word, so acronyms are not preserved.
  String get toTitleCase => replaceAll(RegExp(' +'), ' ')
      .split(' ')
      .map((str) => str.toLetterCase)
      .join(' ');

  String sPluralise(num number) => (number == 1) ? this : '${this}s';
}

extension StringListHelper on List<String> {
  String get toBulletedString => map((item) => '\u2022 $item').join('\n\n');

  String bulletedString({String gap = '\n'}) =>
      map((item) => '\u2022 $item').join(gap);
}

extension ImagePathHelper on String {
  bool get isSvg => endsWith('.svg');

  bool get isWebp => endsWith('.webp');
}
