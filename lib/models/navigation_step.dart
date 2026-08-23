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

  String get instruction {
    final maneuverType = type.toLowerCase().trim();
    final maneuverModifier = modifier.toLowerCase().trim();

    if (maneuverType == 'arrive') return 'Вы прибыли';
    if (maneuverType == 'depart') return 'Начните движение';
    if (maneuverType == 'roundabout' || maneuverType == 'rotary') {
      return 'Въезжайте на круговое движение';
    }

    if (maneuverType == 'merge') {
      if (_isLeft(maneuverModifier)) return 'Перестройтесь левее';
      if (_isRight(maneuverModifier)) return 'Перестройтесь правее';
      return 'Перестройтесь в поток';
    }

    if (maneuverType == 'fork') {
      if (_isLeft(maneuverModifier)) return 'Держитесь левее';
      if (_isRight(maneuverModifier)) return 'Держитесь правее';
    }

    if (maneuverType == 'uturn' || maneuverModifier == 'uturn') {
      return 'Развернитесь';
    }

    switch (maneuverModifier) {
      case 'left':
      case 'sharp left':
        return 'Поверните налево';
      case 'right':
      case 'sharp right':
        return 'Поверните направо';
      case 'slight left':
        return 'Держитесь левее';
      case 'slight right':
        return 'Держитесь правее';
      case 'straight':
        return 'Продолжайте прямо';
      default:
        return 'Продолжайте движение';
    }
  }

  static bool _isLeft(String value) => value.contains('left');

  static bool _isRight(String value) => value.contains('right');
}
