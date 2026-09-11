import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/solid_circle_button.dart';

/// The header of a pushed tool screen: a solid back button, a centred title,
/// and an optional trailing action. Solid on purpose — on a tool screen the
/// specimen is the only glass.
class ToolTopBar extends StatelessWidget {
  const ToolTopBar({required this.title, this.trailing, super.key});

  final String title;

  /// Usually a `SolidCircleButton`, such as a reset.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s4,
        ),
        child: Row(
          children: [
            SolidCircleButton(
              icon: AssetPaths.caretLeft,
              semanticLabel: context.l10n.back,
              onPressed: () => context.pop(),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.headline,
              ),
            ),
            trailing ??
                const SizedBox.square(dimension: SolidCircleButton.target),
          ],
        ),
      ),
    );
  }
}
