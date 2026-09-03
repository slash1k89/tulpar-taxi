const _months = <String>[
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

const kazakhstanUtcOffset = Duration(hours: 5);

/// Converts an instant to Kazakhstan civil time for display only.
///
/// The returned UTC-tagged value is intentionally used only for its calendar
/// components, so formatting never depends on the device timezone.
DateTime toKazakhstanTime(DateTime value) =>
    value.toUtc().add(kazakhstanUtcOffset);

String formatIntercityRideDate(DateTime? value) {
  if (value == null) return 'Дата не указана';
  final kazakhstan = toKazakhstanTime(value);
  return '${kazakhstan.day} ${_months[kazakhstan.month - 1]}';
}

String formatIntercityRideTime(DateTime? value) {
  if (value == null) return '--:--';
  final kazakhstan = toKazakhstanTime(value);
  return '${kazakhstan.hour.toString().padLeft(2, '0')}:'
      '${kazakhstan.minute.toString().padLeft(2, '0')}';
}

String formatKazakhstanDateTime(DateTime value) {
  final kazakhstan = toKazakhstanTime(value);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(kazakhstan.day)}.${two(kazakhstan.month)}.'
      '${kazakhstan.year}, ${two(kazakhstan.hour)}:'
      '${two(kazakhstan.minute)}';
}

String formatIntercityCalendarDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.'
    '${value.year}';

String formatTenge(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}$buffer ₸';
}
