import 'dart:math' as math;

import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_bar.dart';

/// Where the floating tab bar sits, and how much room it takes from a screen.
abstract class ShellInsets {
  static const double _gap = AppSpacing.s12;

  /// The tab bar's distance from the bottom edge: clear of the home
  /// indicator where there is one, never flush where there is not.
  static double tabBarBottom(BuildContext context) =>
      math.max(MediaQuery.paddingOf(context).bottom, AppSpacing.s12);

  /// Space a scrollable leaves at its end so the last item clears the bar.
  static double bottomClearance(BuildContext context) =>
      tabBarBottom(context) + GlassTabBar.heightWithLabels + _gap;
}
