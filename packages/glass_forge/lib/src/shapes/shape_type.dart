/// The SDF branch a shape resolves to inside the geometry shader.
///
/// The integer codes cross the Dart/GLSL boundary as uniform data. They are
/// part of the shader contract: changing one silently changes which distance
/// function a shape renders with, so they are pinned by test.
enum ShapeType {
  /// No shape. The shader returns a large positive distance for this slot.
  none(0),

  /// A rounded rectangle with a uniform corner radius.
  roundedRectangle(1),

  /// An ellipse, solved by Newton iteration rather than the cheap closed form.
  ellipse(2),

  /// A rounded superellipse matching Flutter's own `RoundedSuperellipse`.
  superellipse(3);

  const ShapeType(this.sdfCode);

  /// The integer this type is encoded as in shape uniform data.
  final int sdfCode;
}
