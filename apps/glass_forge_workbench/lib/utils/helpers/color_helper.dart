import 'package:flutter/material.dart';
import 'package:glass_forge_workbench/constants/app_colors.dart';

class ColorHelper {
  ColorHelper._();

  /// Canonical name -> color map driving both [nameToColor] and [colorToName].
  static final Map<String, Color> _namedColors = {
    'White': const Color(0xFFFFFFFF),
    'Red': const Color(0xFFFF0000),
    'Yellow': const Color(0xFFFFFF00),
    'Blue': const Color(0xFF0000FF),
    'Green': const Color(0xFF90EE90),
    'Purple': const Color(0xFF800080),
    'Cyan': const Color(0xFF00FFFF),
    'Dark Red': const Color(0xFF8B0000),
    'Black': AppColors.primary,
    'Orange': Colors.orange,
    'Pink': Colors.pink,
    'Brown': Colors.brown,
    'Grey': Colors.grey,
    'Navy': const Color(0xFF000080),
    'Beige': const Color(0xFFF5F5DC),
    'Cream': const Color(0xFFFFFDD0),
    'Maroon': const Color(0xFF800000),
    'Teal': const Color(0xFF008080),
    'Gold': const Color(0xFFFFD700),
    'Silver': const Color(0xFFC0C0C0),
    'Coral': const Color(0xFFFF7F50),
    'Mint': const Color(0xFF98FF98),
    'Lavender': const Color(0xFFE6E6FA),
  };

  static String colorToName(Color color) {
    for (final entry in _namedColors.entries) {
      if (entry.value.toARGB32() == color.toARGB32()) return entry.key;
    }
    return 'Unknown';
  }

  static Color nameToColor(String name) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return Colors.grey;
    if (key == 'gray') return Colors.grey;
    for (final entry in _namedColors.entries) {
      if (entry.key.toLowerCase() == key) return entry.value;
    }
    return AppColors.textPrimary;
  }
}
