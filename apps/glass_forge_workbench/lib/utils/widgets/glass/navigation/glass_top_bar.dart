import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_circle_button.dart';

/// A title between two optional glass circle buttons, inside the top safe
/// area. The title itself is not glass: glass is for the controls.
class GlassTopBar extends StatelessWidget {
  const GlassTopBar({
    required this.title,
    this.leading,
    this.trailing,
    super.key,
  });

  static const double height = 52;

  final String title;

  /// Usually a [GlassCircleButton].
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s12,
          ),
          child: Row(
            children: [
              leading ??
                  const SizedBox.square(dimension: GlassCircleButton.target),
              Expanded(
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.title,
                    ),
                  ),
                ),
              ),
              trailing ??
                  const SizedBox.square(dimension: GlassCircleButton.target),
            ],
          ),
        ),
      ),
    );
  }
}
