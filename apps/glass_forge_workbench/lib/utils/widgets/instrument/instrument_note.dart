import 'package:glass_forge_workbench/exports.dart';

/// A short paragraph inside an `InstrumentPanel`, for the thing a readout
/// cannot say on its own.
///
/// Deliberately plain — no icon, no tinted box, no border. A note that
/// looked like an alert would compete with the rows it is explaining.
class InstrumentNote extends StatelessWidget {
  /// Creates the note.
  const InstrumentNote({required this.text, super.key});

  /// The note's copy. One or two sentences.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.caption.copyWith(
        color: AppColors.stageForegroundSubtle,
        height: 1.5,
      ),
    );
  }
}
