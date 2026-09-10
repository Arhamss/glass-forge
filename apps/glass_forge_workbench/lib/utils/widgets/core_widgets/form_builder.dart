import 'package:glass_forge_workbench/exports.dart';

class FormBuilder extends StatelessWidget {
  const FormBuilder({
    required this.controllers,
    required this.builder,
    super.key,
    this.validator,
  });

  final List<TextEditingController> controllers;
  final Widget Function(BuildContext context, bool isValid) builder;
  final bool Function(List<TextEditingController> controllers)? validator;

  bool _isValid() {
    if (validator != null) return validator!(controllers);
    return controllers.every((c) => c.text.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(controllers),
      builder: (context, _) => builder(context, _isValid()),
    );
  }
}
