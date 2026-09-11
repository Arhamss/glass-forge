import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/data/place_catalog.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';

class ShowcaseAlertsSheet extends StatelessWidget {
  const ShowcaseAlertsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.notifications, style: context.title),
        const SizedBox(height: AppSpacing.s16),
        for (final alert in PlaceCatalog.alerts) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsetsDirectional.only(top: 2),
                child: AppSvgIcon(
                  AssetPaths.bell,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title, style: context.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      alert.body,
                      style: context.calloutRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Text(
                alert.timeAgo,
                style: context.monoSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
        ],
        Text(
          l10n.notificationsAllRead,
          style: context.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
