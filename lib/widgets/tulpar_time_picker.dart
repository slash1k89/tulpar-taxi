import 'package:flutter/material.dart';

const int tulparTimeMinuteStep = 5;

Future<TimeOfDay?> showTulparTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TulparTimePicker(initialTime: initialTime),
  );
}

TimeOfDay roundTulparTime(TimeOfDay value) {
  final minutes = value.hour * 60 + value.minute;
  final rounded =
      ((minutes + tulparTimeMinuteStep ~/ 2) ~/ tulparTimeMinuteStep) *
      tulparTimeMinuteStep;
  final normalized = rounded.clamp(0, 24 * 60 - tulparTimeMinuteStep).toInt();
  return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
}

class TulparTimePicker extends StatefulWidget {
  const TulparTimePicker({super.key, required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<TulparTimePicker> createState() => _TulparTimePickerState();
}

class _TulparTimePickerState extends State<TulparTimePicker> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    final rounded = roundTulparTime(widget.initialTime);
    _hour = rounded.hour;
    _minute = rounded.minute;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('tulpar_time_picker'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Выберите время',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _formatTime(_hour, _minute),
                key: const Key('tulpar_time_value'),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text('Часы', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _ChoiceGrid(
                itemCount: 24,
                value: _hour,
                keyPrefix: 'tulpar_time_hour',
                onSelected: (value) => setState(() => _hour = value),
              ),
              const SizedBox(height: 20),
              Text('Минуты', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _ChoiceGrid(
                itemCount: 12,
                value: _minute ~/ tulparTimeMinuteStep,
                keyPrefix: 'tulpar_time_minute',
                labelValue: (index) => index * tulparTimeMinuteStep,
                onSelected: (value) =>
                    setState(() => _minute = value * tulparTimeMinuteStep),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const Key('tulpar_time_cancel'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('tulpar_time_done'),
                      onPressed: () => Navigator.pop(
                        context,
                        TimeOfDay(hour: _hour, minute: _minute),
                      ),
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

class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({
    required this.itemCount,
    required this.value,
    required this.keyPrefix,
    required this.onSelected,
    this.labelValue,
  });

  final int itemCount;
  final int value;
  final String keyPrefix;
  final ValueChanged<int> onSelected;
  final int Function(int index)? labelValue;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 64,
      mainAxisExtent: 48,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: itemCount,
    itemBuilder: (context, index) {
      final label = labelValue?.call(index) ?? index;
      return ChoiceChip(
        key: Key('${keyPrefix}_${label.toString().padLeft(2, '0')}'),
        label: SizedBox(
          width: double.infinity,
          child: Text(
            label.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
          ),
        ),
        selected: value == index,
        onSelected: (_) => onSelected(index),
        showCheckmark: false,
        padding: EdgeInsets.zero,
      );
    },
  );
}

String _formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:'
    '${minute.toString().padLeft(2, '0')}';
