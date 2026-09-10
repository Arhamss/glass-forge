import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:glass_forge_workbench/app/view/app_view.dart';
import 'package:glass_forge_workbench/core/locale/cubit/locale_cubit.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/onboarding/data/repository/onboarding_repository_impl.dart';
import 'package:glass_forge_workbench/features/onboarding/presentation/cubit/cubit.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Phoenix(
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => LocaleCubit(context: context),
          ),
          BlocProvider(
            create: (context) => OnboardingCubit(
              repository: OnboardingRepositoryImpl(),
            ),
          ),
        ],
        child: const AppView(),
      ),
    );
  }
}
