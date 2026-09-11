import 'package:glass_forge/glass_forge.dart';

/// Writes a material as the Dart that rebuilds it, so a look tuned by eye
/// pastes straight into an app.
///
/// Only fields that differ from `const GlassMaterial()` are written: the
/// output is the smallest literal that means the same thing.
abstract class GlassMaterialCode {
  static String of(GlassMaterial material) {
    const base = GlassMaterial();
    final direction = material.lightDirection;
    final fields = <String>[
      if (material.variant != base.variant)
        'variant: GlassVariant.${material.variant.name}',
      if (material.profile != base.profile)
        'profile: GlassProfile.${material.profile.name}',
      if (material.thickness != base.thickness)
        'thickness: ${_number(material.thickness)}',
      if (material.edgeRefraction != base.edgeRefraction)
        'edgeRefraction: ${_number(material.edgeRefraction)}',
      if (material.refractionSpread != base.refractionSpread)
        'refractionSpread: ${_number(material.refractionSpread)}',
      if (material.frost != base.frost) 'frost: ${_number(material.frost)}',
      if (material.chromaticAberration != base.chromaticAberration)
        'chromaticAberration: ${_number(material.chromaticAberration)}',
      if (material.tint != base.tint)
        'tint: ${_color(material.tint.toARGB32())}',
      if (material.tintOpacity != base.tintOpacity)
        'tintOpacity: ${_number(material.tintOpacity)}',
      if (material.saturation != base.saturation)
        'saturation: ${_number(material.saturation)}',
      if (material.highlight != base.highlight)
        'highlight: ${_number(material.highlight)}',
      if (direction != base.lightDirection)
        'lightDirection: Offset(${_number(direction.dx)}, ${_number(direction.dy)})',
      if (material.contour != base.contour)
        'contour: ${_number(material.contour)}',
    ];
    if (fields.isEmpty) return 'const GlassMaterial()';
    return 'const GlassMaterial(\n${fields.map((f) => '  $f,').join('\n')}\n)';
  }

  /// Three decimals at most, and always a decimal point, so the literal is a
  /// double the way the constructor wants it.
  static String _number(double value) {
    final rounded = double.parse(value.toStringAsFixed(3));
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(1)
        : rounded.toString();
  }

  static String _color(int argb) =>
      'Color(0x${argb.toRadixString(16).padLeft(8, '0').toUpperCase()})';
}
