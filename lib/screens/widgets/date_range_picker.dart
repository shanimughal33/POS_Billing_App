import 'package:flutter/material.dart';

class DateRangePickerWidget extends StatelessWidget {
  final void Function(DateTimeRange range)? onRangeChanged;

  const DateRangePickerWidget({Key? key, this.onRangeChanged})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.date_range),
      tooltip: 'Select Date Range',
      onSelected: (value) async {
        DateTime now = DateTime.now();
        DateTimeRange? range;
        if (value == 'Today') {
          range = DateTimeRange(start: now, end: now);
        } else if (value == 'Week') {
          range = DateTimeRange(
            start: now.subtract(Duration(days: now.weekday - 1)),
            end: now,
          );
        } else if (value == 'Month') {
          range = DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          );
        } else if (value == 'Custom') {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(now.year - 2),
            lastDate: now,
            initialDateRange: DateTimeRange(start: now, end: now),
          );
          if (picked != null) range = picked;
        }
        if (range != null && onRangeChanged != null) {
          onRangeChanged!(range);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'Today', child: Text('Today')),
        const PopupMenuItem(value: 'Week', child: Text('This Week')),
        const PopupMenuItem(value: 'Month', child: Text('This Month')),
        const PopupMenuItem(value: 'Custom', child: Text('Custom...')),
      ],
    );
  }
}
