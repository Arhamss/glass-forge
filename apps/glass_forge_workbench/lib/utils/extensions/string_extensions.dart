extension StringExtensions on String {
  String get titleCase {
    if (isEmpty) return '';
    return split(RegExp(r'[_\s]+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
