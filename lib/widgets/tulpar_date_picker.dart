import 'package:flutter/material.dart';

const _monthNames = <String>[
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

const _weekdayNames = <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

Future<DateTime?> showTulparDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? today,
  SelectableDayPredicate? selectableDayPredicate,
}) {
  final first = DateUtils.dateOnly(firstDate);
  final last = DateUtils.dateOnly(lastDate);
  assert(!last.isBefore(first), 'lastDate must be on or after firstDate');

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TulparDatePicker(
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
      today: today,
      selectableDayPredicate: selectableDayPredicate,
    ),
  );
}

class TulparDatePicker extends StatefulWidget {
  const TulparDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.today,
    this.selectableDayPredicate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? today;
  final SelectableDayPredicate? selectableDayPredicate;

  @override
  State<TulparDatePicker> createState() => _TulparDatePickerState();
}

class _TulparDatePickerState extends State<TulparDatePicker> {
  late final DateTime _firstDate;
  late final DateTime _lastDate;
  late final DateTime _today;
  late DateTime _selectedDate;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _firstDate = DateUtils.dateOnly(widget.firstDate);
    _lastDate = DateUtils.dateOnly(widget.lastDate);
    _today = DateUtils.dateOnly(widget.today ?? DateTime.now());
    _selectedDate = _initialSelectableDate();
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  DateTime _initialSelectableDate() {
    var value = DateUtils.dateOnly(widget.initialDate);
    if (value.isBefore(_firstDate)) value = _firstDate;
    if (value.isAfter(_lastDate)) value = _lastDate;
    if (_isSelectable(value)) return value;

    for (var offset = 1; ; offset++) {
      final after = value.add(Duration(days: offset));
      final before = value.subtract(Duration(days: offset));
      final canTryAfter = !after.isAfter(_lastDate);
      final canTryBefore = !before.isBefore(_firstDate);
      if (!canTryAfter && !canTryBefore) return value;
      if (canTryAfter && _isSelectable(after)) return after;
      if (canTryBefore && _isSelectable(before)) return before;
    }
  }

  bool _isSelectable(DateTime date) {
    final day = DateUtils.dateOnly(date);
    if (day.isBefore(_firstDate) || day.isAfter(_lastDate)) return false;
    return widget.selectableDayPredicate?.call(day) ?? true;
  }

  bool _sameMonth(DateTime left, DateTime right) =>
      left.year == right.year && left.month == right.month;

  bool get _canGoPrevious => !_sameMonth(_displayedMonth, _firstDate);
  bool get _canGoNext => !_sameMonth(_displayedMonth, _lastDate);

  void _changeMonth(int offset) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + offset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
          child: Column(
            key: const Key('tulpar_date_picker'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    key: const Key('tulpar_date_previous_month'),
                    tooltip: 'Предыдущий месяц',
                    onPressed: _canGoPrevious ? () => _changeMonth(-1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthNames[_displayedMonth.month - 1]} '
                      '${_displayedMonth.year}',
                      key: const Key('tulpar_date_month'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('tulpar_date_next_month'),
                    tooltip: 'Следующий месяц',
                    onPressed: _canGoNext ? () => _changeMonth(1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: _weekdayNames
                    .map(
                      (name) => Expanded(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 4),
              _MonthGrid(
                month: _displayedMonth,
                selectedDate: _selectedDate,
                today: _today,
                isSelectable: _isSelectable,
                onSelected: (date) => setState(() => _selectedDate = date),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const Key('tulpar_date_cancel'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('tulpar_date_done'),
                      onPressed: _isSelectable(_selectedDate)
                          ? () => Navigator.pop(
                              context,
                              DateUtils.dateOnly(_selectedDate),
                            )
                          : null,
                      child: const Text('Готово'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.today,
    required this.isSelectable,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final DateTime today;
  final bool Function(DateTime date) isSelectable;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final firstDayOffset = DateTime(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final rowCount = ((firstDayOffset + daysInMonth) / 7).ceil();

    return GridView.builder(
      key: Key('tulpar_date_grid_${month.year}_${month.month}'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 44,
        mainAxisSpacing: rowCount > 5 ? 2 : 4,
        crossAxisSpacing: 4,
      ),
      itemCount: rowCount * 7,
      itemBuilder: (context, index) {
        final dayNumber = index - firstDayOffset + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }
        final date = DateTime(month.year, month.month, dayNumber);
        return _DayButton(
          date: date,
          selected: DateUtils.isSameDay(date, selectedDate),
          today: DateUtils.isSameDay(date, today),
          enabled: isSelectable(date),
          onPressed: () => onSelected(date),
        );
      },
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.date,
    required this.selected,
    required this.today,
    required this.enabled,
    required this.onPressed,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onPrimary
        : enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);

    return Semantics(
      selected: selected,
      button: true,
      child: TextButton(
        key: Key(
          'tulpar_date_day_${date.year}_'
          '${date.month.toString().padLeft(2, '0')}_'
          '${date.day.toString().padLeft(2, '0')}',
        ),
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: foreground,
          backgroundColor: selected ? colors.primary : Colors.transparent,
          shape: CircleBorder(
            side: today && !selected
                ? BorderSide(color: colors.primary)
                : BorderSide.none,
          ),
        ),
        child: Text('${date.day}'),
      ),
    );
  }
}
