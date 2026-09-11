import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/haptic_helper.dart';
import 'package:glass_forge_workbench/utils/helpers/tab_geometry.dart';

/// Builds a row of equal segments from where the selector should be, which
/// segment reads as selected, and a callback for a tap on segment `i`.
typedef SegmentScrubBuilder =
    Widget Function(
      BuildContext context,
      double alignment,
      int shownIndex,
      ValueChanged<int> select,
    );

/// Tap-or-scrub selection across equal segments, shared by the tab bar and
/// the segmented control.
///
/// Dragging moves the selector with the finger and ticks a haptic at every
/// segment boundary; lifting commits the segment under it.
class SegmentScrubber extends StatefulWidget {
  const SegmentScrubber({
    required this.count,
    required this.currentIndex,
    required this.onChanged,
    required this.builder,
    this.inset = 0,
    super.key,
  });

  final int count;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final SegmentScrubBuilder builder;

  /// Padding around the segments, which the finger's position is measured
  /// inside of.
  final double inset;

  @override
  State<SegmentScrubber> createState() => _SegmentScrubberState();
}

class _SegmentScrubberState extends State<SegmentScrubber> {
  // The selector's alignment and the segment under the finger, while a scrub
  // is in progress.
  final ValueNotifier<(double, int)?> _scrub = ValueNotifier(null);

  @override
  void dispose() {
    _scrub.dispose();
    super.dispose();
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  void _select(int index) {
    if (index == widget.currentIndex) return;
    AppHaptics.tap();
    widget.onChanged(index);
  }

  void _scrubTo(double localX, double width) {
    final x = localX - widget.inset;
    final index = TabGeometry.indexAt(x, width, widget.count, rtl: _rtl);
    if (index != _scrub.value?.$2) AppHaptics.toggle();
    _scrub.value = (
      TabGeometry.alignAt(x, width, widget.count, rtl: _rtl),
      index,
    );
  }

  void _endScrub() {
    final index = _scrub.value?.$2;
    _scrub.value = null;
    if (index != null) _select(index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - widget.inset * 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _scrubTo(d.localPosition.dx, width),
          onHorizontalDragUpdate: (d) => _scrubTo(d.localPosition.dx, width),
          onHorizontalDragEnd: (_) => _endScrub(),
          onHorizontalDragCancel: () => _scrub.value = null,
          child: Padding(
            padding: EdgeInsetsDirectional.all(widget.inset),
            child: ValueListenableBuilder<(double, int)?>(
              valueListenable: _scrub,
              builder: (context, scrub, _) => widget.builder(
                context,
                scrub?.$1 ??
                    TabGeometry.alignFor(widget.currentIndex, widget.count),
                scrub?.$2 ?? widget.currentIndex,
                _select,
              ),
            ),
          ),
        );
      },
    );
  }
}
