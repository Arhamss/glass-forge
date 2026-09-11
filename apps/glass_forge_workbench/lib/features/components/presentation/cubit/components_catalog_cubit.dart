import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/components_catalog_state.dart';

class ComponentsCatalogCubit extends Cubit<ComponentsCatalogState> {
  ComponentsCatalogCubit() : super(const ComponentsCatalogState());

  void setQuery(String query) => emit(state.copyWith(query: query));
}
