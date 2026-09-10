/// The maximum number of shapes a single geometry pass can carry.
///
/// This is derived from the uniform-buffer budget, not yet confirmed on
/// device. Upstream's equivalent is 16, from six floats per shape hitting
/// Impeller's uniform-buffer limit of 96 floats. Our layout is wider — three
/// `vec4` per shape, because it carries an inverse affine basis so rotated
/// and non-uniformly scaled shapes refract in the right direction — so
/// upstream's number does not transfer: 96 floats / 12 floats per shape = 8.
///
/// Raise this only after re-running the probe on the weakest backend you
/// intend to support, and update [kMaxShapesProvenance] with what you saw.
const int kMaxShapes = 8;

/// The uniform-array float budget the shape data must fit inside.
///
/// Impeller reports no documented numeric cap, so treat this as
/// device-dependent. 96 is the figure upstream hit in practice on Impeller.
const int kMaxShapeFloats = 96;

/// Where [kMaxShapes] came from.
const String kMaxShapesProvenance =
    'Derived, pending device confirmation. Our layout is 3 vec4 (12 floats) '
    'per shape to carry an inverse affine basis, against the 96-float budget '
    'upstream hit on Impeller: 96 / 12 = 8. Upstream fits 16 only because its '
    '6-float layout cannot express rotation. Confirm with shaders/probe.frag '
    'on Impeller-Vulkan, Impeller-GLES and Metal before raising.';
