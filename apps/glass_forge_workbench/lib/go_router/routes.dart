part of 'exports.dart';

class AppRoutes {
  AppRoutes._();

  static const showcase = '/showcase';
  static const components = '/components';
  static const material = '/material';
  static const lab = '/lab';

  /// A component's playground, as a child of [components].
  static const playground = ':component';

  // Lab tools, as children of [lab]: each opens full-screen above the shell.
  static const labTiers = 'tiers';
  static const labBlend = 'blend';
  static const labMotion = 'motion';
  static const labSurfaces = 'surfaces';
  static const labSamplingProbe = 'sampling-probe';
}

class AppRouteNames {
  AppRouteNames._();

  static const showcase = 'showcase';
  static const components = 'components';
  static const material = 'material';
  static const lab = 'lab';
  static const playground = 'playground';
  static const labTiers = 'labTiers';
  static const labBlend = 'labBlend';
  static const labMotion = 'labMotion';
  static const labSurfaces = 'labSurfaces';
  static const labSamplingProbe = 'labSamplingProbe';
}
