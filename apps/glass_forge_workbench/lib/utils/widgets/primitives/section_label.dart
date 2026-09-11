import 'package:glass_forge_workbench/exports.dart';

/// A small upper-case label heading a group of rows.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: context.overline.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}
