import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/cubit/showcase_cubit.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/showcase_feed.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/showcase_header.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/showcase_player_dock.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/showcase_top_scrim.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_top_bar.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_mini_player.dart';
import 'package:glass_forge_workbench/utils/widgets/layout/shell_insets.dart';

/// A travel app's front page, built from nothing but the glass kit: the feed
/// scrolls under a glass header, a glass player and the glass tab bar.
class ShowcaseView extends StatelessWidget {
  const ShowcaseView({super.key});

  static const double _dockGap = AppSpacing.s12;

  @override
  Widget build(BuildContext context) {
    final headerHeight = ShowcaseHeader.heightOf(context);
    final dockBottom = ShellInsets.bottomClearance(context);
    return BlocProvider(
      create: (_) => ShowcaseCubit(),
      child: Scaffold(
        backgroundColor: AppColors.ground,
        resizeToAvoidBottomInset: false,
        // Expanded, with the header and scrim positioned: a loose stack sizes
        // itself to its largest unpositioned child, which here would be the
        // header, and would squeeze the feed and pin the dock to the top.
        body: Stack(
          fit: StackFit.expand,
          children: [
            ShowcaseFeed(
              topInset: headerHeight,
              bottomInset: dockBottom + GlassMiniPlayer.height + _dockGap,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ShowcaseTopScrim(
                height: headerHeight + AppSpacing.s24,
                solidUntil:
                    MediaQuery.paddingOf(context).top + GlassTopBar.height,
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ShowcaseHeader(),
            ),
            PositionedDirectional(
              start: AppSpacing.gutter,
              end: AppSpacing.gutter,
              bottom: dockBottom - AppSpacing.s4,
              child: const ShowcasePlayerDock(),
            ),
          ],
        ),
      ),
    );
  }
}
