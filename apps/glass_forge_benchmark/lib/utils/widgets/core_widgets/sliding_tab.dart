import 'package:glass_forge_benchmark/exports.dart';

class SlidingTab extends StatefulWidget {
  const SlidingTab({
    required this.labels,
    required this.onTapCallbacks,
    this.height,
    this.width,
    this.selectedColor,
    this.backgroundColor,
    this.borderColor,
    this.initialIndex = 0,
    this.shortenWidth = false,
    this.borderRadius = 100,
    super.key,
  }) : assert(
         labels.length == onTapCallbacks.length &&
             (labels.length == 2 || labels.length == 3),
         'labels and onTapCallbacks must be of equal length and contain either 2 or 3 items.',
       );

  final List<String> labels;
  final List<VoidCallback> onTapCallbacks;
  final double? height;
  final double? width;
  final Color? selectedColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final int initialIndex;
  final bool shortenWidth;
  final double borderRadius;

  @override
  State<SlidingTab> createState() => _SlidingTabState();
}

class _SlidingTabState extends State<SlidingTab> {
  late int selectedIndex;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(SlidingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      selectedIndex = widget.initialIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullWidth = MediaQuery.of(context).size.width;
    final containerWidth = widget.width ?? fullWidth;
    final tabCount = widget.labels.length;

    final tabWidth1 = widget.shortenWidth
        ? containerWidth / (tabCount + 0.5)
        : containerWidth / tabCount;

    final tabWidth2 = widget.shortenWidth
        ? containerWidth / (tabCount + 0.1)
        : containerWidth / tabCount;

    final tabWidth3 = widget.shortenWidth
        ? containerWidth / (tabCount + 0.45)
        : containerWidth / tabCount;

    return Container(
      width: containerWidth,
      height: widget.height ?? 48,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? AppColors.primary,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.borderColor != null
            ? Border.all(color: widget.borderColor!)
            : null,
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment(
              -1.0 + (2.0 * selectedIndex / (tabCount - 1)),
              0,
            ),
            child: Container(
              width: selectedIndex == 0
                  ? tabWidth1
                  : selectedIndex == 1
                  ? tabWidth2
                  : tabWidth3,
              height: widget.height ?? 48,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.selectedColor ?? AppColors.primary,
                borderRadius: BorderRadius.circular(widget.borderRadius - 4),
              ),
            ),
          ),
          Row(
            children: List.generate(tabCount, (index) {
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() {
                      selectedIndex = index;
                    });
                    widget.onTapCallbacks[index]();
                  },
                  child: Container(
                    height: widget.height ?? 48,
                    alignment: Alignment.center,
                    child: Text(
                      widget.labels[index],
                      textAlign: TextAlign.center,
                      style: context.captionMedium,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
