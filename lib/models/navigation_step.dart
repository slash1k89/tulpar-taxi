class NavigationStep {
  final String modifier;
  final String type;
  final double targetLat;
  final double targetLng;
  final String streetName;
  final double distanceMeters;
  final double durationSeconds;
  final int? exitNumber;

  const NavigationStep({
    required this.modifier,
    required this.type,
    required this.targetLat,
    required this.targetLng,
    required this.streetName,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.exitNumber,
  });

  factory NavigationStep.fromJson(Map json) {
    final maneuver = json['maneuver'] as Map? ?? {};
    final location = maneuver['location'];
    if (location is! List || location.length < 2) {
      throw const FormatException('Navigation maneuver location is missing.');
    }
    final targetLng = _coordinate(location[0], min: -180, max: 180);
    final targetLat = _coordinate(location[1], min: -90, max: 90);

    return NavigationStep(
      modifier: maneuver['modifier']?.toString() ?? 'straight',
      type: maneuver['type']?.toString() ?? 'turn',
      targetLng: targetLng,
      targetLat: targetLat,
      streetName: json['name']?.toString() ?? '',
      distanceMeters: _nonNegativeDouble(json['distanceMeters']),
      durationSeconds: _nonNegativeDouble(json['durationSeconds']),
      exitNumber: _positiveInteger(maneuver['exit']),
    );
  }
}

double _coordinate(Object? value, {required double min, required double max}) {
  if (value is! num) {
    throw const FormatException('Invalid navigation maneuver coordinate.');
  }
  final coordinate = value.toDouble();
  if (!coordinate.isFinite || coordinate < min || coordinate > max) {
    throw const FormatException('Invalid navigation maneuver coordinate.');
  }
  return coordinate;
}

double _nonNegativeDouble(Object? value) {
  if (value is! num) return 0;
  final parsed = value.toDouble();
  return parsed.isFinite && parsed >= 0 ? parsed : 0;
}

int? _positiveInteger(Object? value) {
  if (value is! num || !value.isFinite) return null;
  final parsed = value.toInt();
  return parsed > 0 && parsed == value ? parsed : null;
}
