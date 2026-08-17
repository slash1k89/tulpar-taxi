class NavigationStep {
  final String modifier;
  final String type;
  final double targetLat;
  final double targetLng;
  final String streetName;

  NavigationStep({
    required this.modifier,
    required this.type,
    required this.targetLat,
    required this.targetLng,
    required this.streetName,
  });

  factory NavigationStep.fromJson(Map json) {
    final maneuver = json['maneuver'] as Map? ?? {};
    final location = (maneuver['location'] as List?) ?? [0.0, 0.0];

    return NavigationStep(
      modifier: maneuver['modifier']?.toString() ?? 'straight',
      type: maneuver['type']?.toString() ?? 'turn',
      targetLng: (location[0] as num).toDouble(),
      targetLat: (location[1] as num).toDouble(),
      streetName: json['name']?.toString() ?? '',
    );
  }
}