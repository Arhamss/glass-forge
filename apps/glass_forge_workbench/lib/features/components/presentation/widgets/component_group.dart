import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/component_row.dart';
import 'package:glass_forge_workbench/utils/enums/component_family.dart';
import 'package:glass_forge_workbench/utils/enums/component_id.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/section_label.dart';

/// One family's heading and its rows, on one surface with hairlines between.
class ComponentGroup extends StatelessWidget {
  const ComponentGroup({
    required this.family,
    required this.components,
    this.onOpen,
    super.key,
  });

  final ComponentFamily family;
  final List<ComponentId> components;

  /// Null while the playgrounds are not wired, which shows rows without a
  /// destination.
  final ValueChanged<ComponentId>? onOpen;

  @override
  Widget build(BuildContext context) {
    final onOpen = this.onOpen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.s4),
          child: SectionLabel(family.label),
        ),
        const SizedBox(height: AppSpacing.s8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r24),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            children: [
              for (final component in components) ...[
                if (component != components.first)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    color: AppColors.hairline,
                  ),
                ComponentRow(
                  component: component,
                  onTap: onOpen == null ? null : () => onOpen(component),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
