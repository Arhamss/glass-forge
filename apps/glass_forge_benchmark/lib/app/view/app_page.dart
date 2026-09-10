import 'package:glass_forge_benchmark/app/view/app_view.dart';
import 'package:glass_forge_benchmark/core/locale/cubit/locale_cubit.dart';
import 'package:glass_forge_benchmark/exports.dart';

/// Root of the benchmark harness.
///
/// Deliberately shallow: every provider mounted here is present in the widget
/// tree during the frames this app exists to measure, so only what the harness
/// itself needs belongs above [AppView].
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LocaleCubit(context: context),
      child: const AppView(),
    );
  }
}
