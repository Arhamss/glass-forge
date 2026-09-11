import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/tool/tool_top_bar.dart';

/// Puts a Lab tool under a top bar with a way back.
///
/// The tool below keeps its own layout; it just no longer sits under the
/// status bar, so its stage loses the top inset it used to reserve.
class LabToolFrame extends StatelessWidget {
  const LabToolFrame({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: Column(
        children: [
          ToolTopBar(title: title),
          Expanded(
            child: SafeArea(
              top: false,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
