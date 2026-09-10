import 'package:flutter/cupertino.dart';
import 'package:glass_forge_benchmark/exports.dart';

enum CustomInlineDatePickerMode {
  past, // Can't pick dates after now
  future, // Can't pick dates before now
}

class CustomInlineDatePicker extends StatefulWidget {
  const CustomInlineDatePicker({
    required this.onDateSelected,
    this.mode = CustomInlineDatePickerMode.past,
    super.key,
    this.firstDate,
    this.lastDate,
    this.initialDate,
  });

  final dynamic Function(DateTime) onDateSelected;
  final CustomInlineDatePickerMode mode;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? initialDate;

  @override
  State<CustomInlineDatePicker> createState() => _CustomInlineDatePickerState();
}

class _CustomInlineDatePickerState extends State<CustomInlineDatePicker> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDate = widget.mode == CustomInlineDatePickerMode.past
        ? widget.firstDate ?? DateTime(1900)
        : now;
    final lastDate = widget.mode == CustomInlineDatePickerMode.past
        ? now
        : widget.lastDate ?? DateTime(2100);

    final initialDate = widget.initialDate ?? now;
    final validInitialDate = initialDate.isBefore(firstDate)
        ? firstDate
        : initialDate.isAfter(lastDate)
        ? lastDate
        : initialDate;

    return SizedBox(
      height: 200,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: validInitialDate,
        minimumDate: firstDate,
        maximumDate: lastDate,
        onDateTimeChanged: widget.onDateSelected,
        backgroundColor: AppColors.surface,
      ),
    );
  }
}
