DateTime? intercityDateTime(Object? value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

int intercityInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double? intercityDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String intercityString(Object? value) => value?.toString() ?? '';

Map<String, dynamic>? intercityMap(Object? value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}
