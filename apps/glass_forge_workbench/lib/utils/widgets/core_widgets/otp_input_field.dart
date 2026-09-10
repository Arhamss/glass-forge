import 'package:glass_forge_workbench/exports.dart';

class CustomOtpField extends StatefulWidget {
  const CustomOtpField({
    required this.controller,
    super.key,
    this.length = 6,
    this.autofocus = true,
    this.onCompleted,
    this.fieldWidth = 48,
    this.fieldHeight = 54,
    this.borderRadius = 12,
    this.fillColor,
    this.focusedBorderColor,
    this.errorBorderColor,
    this.textStyle,
    this.enableHaptics = false,
  });

  final TextEditingController controller;
  final int length;
  final bool autofocus;
  final ValueChanged<String>? onCompleted;
  final double fieldWidth;
  final double fieldHeight;
  final double borderRadius;
  final Color? fillColor;
  final Color? focusedBorderColor;
  final Color? errorBorderColor;
  final TextStyle? textStyle;
  final bool enableHaptics;

  @override
  State<CustomOtpField> createState() => _CustomOtpFieldState();
}

class _CustomOtpFieldState extends State<CustomOtpField> {
  late final TextEditingController _hiddenController;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _hiddenController = TextEditingController();
    _hiddenController.addListener(_onTextChanged);

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  void _onTextChanged() {
    final text = _hiddenController.text;
    widget.controller.text = text;
    setState(() {});

    if (widget.enableHaptics && text.isNotEmpty) {
      HapticFeedback.lightImpact();
    }

    if (text.length == widget.length) {
      widget.onCompleted?.call(text);
    }
  }

  @override
  void dispose() {
    _hiddenController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.fillColor ?? AppColors.surface;
    final focusBorder = widget.focusedBorderColor ?? AppColors.primary;
    final radius = BorderRadius.circular(widget.borderRadius);
    final style = widget.textStyle ?? context.p1Bold;
    final text = _hiddenController.text;
    final hasFocus = _focusNode.hasFocus;

    return GestureDetector(
      onTap: _focusNode.requestFocus,
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 0,
              child: TextField(
                controller: _hiddenController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (index) {
              final hasDigit = index < text.length;
              final isActiveField = hasFocus && index == text.length;

              final borderColor = isActiveField
                  ? focusBorder
                  : hasDigit
                      ? AppColors.primary
                      : AppColors.border;

              return Container(
                width: widget.fieldWidth,
                height: widget.fieldHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: radius,
                  border: Border.all(
                    color: borderColor,
                    width: hasDigit ? 0.5 : 1,
                  ),
                ),
                child: hasDigit
                    ? Text(text[index], style: style)
                    : isActiveField
                        ? _BlinkingCursor(color: focusBorder)
                        : const SizedBox.shrink(),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({required this.color});

  final Color color;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(width: 1.5, height: 20, color: widget.color),
    );
  }
}
