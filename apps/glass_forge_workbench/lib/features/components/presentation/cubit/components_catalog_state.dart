import 'package:equatable/equatable.dart';
import 'package:glass_forge_workbench/utils/enums/component_family.dart';
import 'package:glass_forge_workbench/utils/enums/component_id.dart';

class ComponentsCatalogState extends Equatable {
  const ComponentsCatalogState({this.query = ''});

  final String query;

  /// Each family with the components matching [query], in catalog order.
  /// Families with nothing to show are left out.
  List<(ComponentFamily, List<ComponentId>)> get groups {
    final needle = query.trim().toLowerCase();
    bool matches(ComponentId id) =>
        needle.isEmpty ||
        id.title.toLowerCase().contains(needle) ||
        id.summary.toLowerCase().contains(needle) ||
        id.family.label.toLowerCase().contains(needle);
    return [
      for (final family in ComponentFamily.values)
        if (ComponentId.values
                .where((id) => id.family == family && matches(id))
                .toList()
            case final members when members.isNotEmpty)
          (family, members),
    ];
  }

  ComponentsCatalogState copyWith({String? query}) =>
      ComponentsCatalogState(query: query ?? this.query);

  @override
  List<Object?> get props => [query];
}
