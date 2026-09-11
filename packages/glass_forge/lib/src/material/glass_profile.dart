/// How a glass surface bends what is behind it.
///
/// Two different physical models, not two settings of one. No value of any
/// other `GlassMaterial` field turns one into the other.
///
/// [edgeBand] is Apple's: a flat pane that refracts only inside a band at
/// its rim and leaves the interior undistorted. It is the default, and what
/// the fitted presets are fitted against.
///
/// [dome] treats the shape as a sphere cap over its whole interior, the way
/// `liquid_glass_renderer` does. Everything behind it is refracted, so the
/// middle magnifies and the rim compresses — over a backdrop with no hard
/// edges to bend, that difference is the one between a lens and a frosted
/// pane.
enum GlassProfile {
  /// Refraction confined to a band at the rim; the interior stays flat.
  edgeBand,

  /// A sphere cap over the full interior depth, refracted as one slab.
  dome,
}
