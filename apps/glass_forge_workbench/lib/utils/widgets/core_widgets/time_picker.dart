import 'package:flutter/cupertino.dart';
import 'package:glass_forge_workbench/exports.dart';

class CustomTimePicker extends StatefulWidget {
  const CustomTimePicker({
    required this.onTimeSelected,
    super.key,
    this.initialTime,
  });

  final dynamic Function(DateTime) onTimeSelected;

  final DateTime? initialTime;

  @override
  State<CustomTimePicker> createState() => _CustomTimePickerState();
}

class _CustomTimePickerState extends State<CustomTimePicker> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SizedBox(
      height: 200,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: widget.initialTime ?? now,
        onDateTimeChanged: widget.onTimeSelected,
        backgroundColor: AppColors.surface,
      ),
    );
  }
}
