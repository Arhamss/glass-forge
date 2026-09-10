import 'package:glass_forge_workbench/exports.dart';

enum CalendarMode {
  single, // For postpone - single date selection
  dual, // For filters - start and end date selection
}

class ReusableCalendarWidget extends StatefulWidget {
  const ReusableCalendarWidget({
    required this.mode,
    this.onDateSelected,
    this.startDate,
    this.endDate,
    this.selectedDate,
    this.isSelectingEndDate = false,
    this.onStartDateSelected,
    this.onEndDateSelected,
    super.key,
  });

  final CalendarMode mode;
  final dynamic Function(DateTime)? onDateSelected; // For single mode
  final DateTime? startDate; // For dual mode
  final DateTime? endDate; // For dual mode
  final DateTime? selectedDate; // For single mode
  final bool isSelectingEndDate; // For dual mode
  final dynamic Function(DateTime)? onStartDateSelected; // For dual mode
  final dynamic Function(DateTime)? onEndDateSelected; // For dual mode

  @override
  State<ReusableCalendarWidget> createState() => _ReusableCalendarWidgetState();
}

class _ReusableCalendarWidgetState extends State<ReusableCalendarWidget> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Month Navigation
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month - 1,
                      );
                    });
                  },
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                  style: context.p1Medium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month + 1,
                      );
                    });
                  },
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Weekday Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sat', 'Su']
                  .map(
                    (day) => SizedBox(
                      width: 32,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: context.p1Medium.copyWith(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Calendar Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCalendarGrid(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month);
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;
    final now = DateTime.now();

    final days = <Widget>[];

    // Add empty spaces for days before the first day of the month
    for (var i = 1; i < firstWeekday; i++) {
      days.add(const SizedBox(height: 32));
    }

    // Add days of the month
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);

      // Determine if date is selected based on mode
      var isSelected = false;
      var isDisabled = false;

      if (widget.mode == CalendarMode.single) {
        isSelected = widget.selectedDate != null &&
            isSameDay(date, widget.selectedDate!);
        isDisabled = date.isBefore(
          DateTime(now.year, now.month, now.day),
        ); // Past dates disabled
      } else {
        // Dual mode
        final isStartDate =
            widget.startDate != null && isSameDay(date, widget.startDate!);
        final isEndDate =
            widget.endDate != null && isSameDay(date, widget.endDate!);
        isSelected = isStartDate || isEndDate;
        isDisabled = widget.isSelectingEndDate &&
            widget.startDate != null &&
            date.isBefore(widget.startDate!);
      }

      final isToday = isSameDay(date, now);

      days.add(
        GestureDetector(
          onTap: isDisabled ? null : () => _handleDateTap(date),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primary
                      : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.toString(),
                    style: context.p2.copyWith(
                      fontSize: 12,
                      color: isDisabled
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : isSelected
                              ? AppColors.surface
                              : isToday
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                      fontWeight: (isSelected || isToday)
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (isToday) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : isSelected
                                ? AppColors.surface
                                : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: days,
    );
  }

  void _handleDateTap(DateTime date) {
    if (widget.mode == CalendarMode.single) {
      widget.onDateSelected?.call(date);
    } else {
      // Dual mode
      if (widget.isSelectingEndDate) {
        widget.onEndDateSelected?.call(date);
      } else {
        widget.onStartDateSelected?.call(date);
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
