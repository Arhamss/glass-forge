import 'package:glass_forge_workbench/app/view/app_view.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/house_glass/presentation/cubit/house_glass_cubit.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/glass_kit_root.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HouseGlassCubit(),
      child: const GlassKitRoot(child: AppView()),
    );
  }
}
