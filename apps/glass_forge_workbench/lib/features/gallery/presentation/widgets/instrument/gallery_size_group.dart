import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/cubit/gallery_state.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_slider.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_value_row.dart';

/// The size control, and the threshold it is being dragged across.
///
/// The one place on the screen where the gate is the subject rather than a
/// consequence: drag the height past the gate and two of the five roles
/// change what they do.
class GallerySizeGroup extends StatelessWidget {
  /// Creates the group.
  const GallerySizeGroup({
    required this.shortSide,
    required this.maxShortSide,
    required this.onShortSideChanged,
    super.key,
  });

  /// The height every demonstration surface is drawn at.
  final double shortSide;

  /// The tallest the stage can draw right now.
  final double maxShortSide;

  /// Called as the height is dragged.
  final ValueChanged<double> onShortSideChanged;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Size',
      cells: [
        InstrumentSlider(
          label: 'Short side',
          value: shortSide,
          unit: 'px',
          min: GalleryState.minShortSide,
          max: maxShortSide,
          fractionDigits: 0,
          onChanged: onShortSideChanged,
        ),
        InstrumentValueRow(
          label: 'Flip gate',
          value:
              '${GalleryState.tokens.flipMaxShortSide.toStringAsFixed(0)}'
              ' px',
          note:
              'The tallest bar iOS ships is a large-title navigation bar '
              'at 96. Thinner than that and a surface is chrome over one '
              'strip of backdrop, so one flip decision covers all of it. '
              'Thicker and it is carrying content, so it only adapts.',
        ),
      ],
    );
  }
}
