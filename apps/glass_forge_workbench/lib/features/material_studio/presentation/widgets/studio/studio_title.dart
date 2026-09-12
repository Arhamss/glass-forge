import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';

/// The studio's name and what it does.
class StudioTitle extends StatelessWidget {
  const StudioTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.materialTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.display,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.materialSubtitle,
          style: context.calloutRegular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
