import '../models/navigation_step.dart';

enum NavigationManeuverIcon {
  left,
  right,
  slightLeft,
  slightRight,
  sharpLeft,
  sharpRight,
  straight,
  keepLeft,
  keepRight,
  merge,
  ramp,
  uTurn,
  roundaboutLeft,
  roundaboutRight,
  arrive,
  depart,
}

class NavigationInstructionPresentation {
  const NavigationInstructionPresentation({
    required this.instruction,
    required this.icon,
    this.distanceLabel,
    this.streetName,
  });

  final String instruction;
  final NavigationManeuverIcon icon;
  final String? distanceLabel;
  final String? streetName;
}

class NavigationInstructionFormatter {
  const NavigationInstructionFormatter._();

  static NavigationInstructionPresentation format(
    NavigationStep step, {
    double? distanceToManeuverMeters,
    bool arrivalConfirmed = true,
  }) {
    final type = _normalize(step.type);
    final modifier = _normalize(step.modifier);
    final waitingForArrival = type == 'arrive' && !arrivalConfirmed;
    final instruction = waitingForArrival
        ? 'Продолжайте к точке'
        : _instruction(
            type: type,
            modifier: modifier,
            exitNumber: step.exitNumber,
          );
    final street = step.streetName.trim();

    return NavigationInstructionPresentation(
      instruction: instruction,
      icon: waitingForArrival
          ? NavigationManeuverIcon.straight
          : _icon(type: type, modifier: modifier),
      distanceLabel: formatDistancePrefix(distanceToManeuverMeters),
      streetName: street.isEmpty ? null : street,
    );
  }

  static String? formatDistancePrefix(double? meters) {
    if (meters == null || !meters.isFinite || meters < 25) return null;

    if (meters < 100) {
      final rounded = (meters / 10).round() * 10;
      return 'Через $rounded м';
    }
    if (meters < 1000) {
      final rounded = (meters / 50).round() * 50;
      return 'Через $rounded м';
    }

    final kilometers = _formatKilometers(meters);
    return 'Через $kilometers км';
  }

  static String formatSpokenDistance(double meters) {
    if (!meters.isFinite || meters < 0) return '';
    if (meters < 1000) {
      final rounded = meters < 100
          ? (meters / 10).round() * 10
          : (meters / 50).round() * 50;
      return '$rounded ${_metersWord(rounded)}';
    }
    final value = _formatKilometers(meters);
    if (!value.contains(',')) {
      final whole = int.parse(value);
      return '$value ${_kilometersWord(whole)}';
    }
    return '$value километра';
  }

  static String? formatRouteSummary({
    required double? distanceMeters,
    required double? durationSeconds,
  }) {
    if (distanceMeters == null ||
        durationSeconds == null ||
        !distanceMeters.isFinite ||
        !durationSeconds.isFinite ||
        distanceMeters <= 0 ||
        durationSeconds <= 0) {
      return null;
    }

    final distance = distanceMeters < 1000
        ? '${distanceMeters.round()} м'
        : '${(distanceMeters / 1000).toStringAsFixed(1).replaceAll('.', ',')} км';
    final totalMinutes = (durationSeconds / 60).ceil();
    final duration = totalMinutes < 60
        ? '$totalMinutes мин'
        : '${totalMinutes ~/ 60} ч ${totalMinutes % 60} мин';
    return '$distance • $duration';
  }

  static String _instruction({
    required String type,
    required String modifier,
    required int? exitNumber,
  }) {
    if (type == 'arrive') return 'Вы прибыли';
    if (type == 'depart') return 'Начните движение';
    if (type == 'exit roundabout' || type == 'exit rotary') {
      return 'Съезжайте с кольца';
    }
    if (_isRoundabout(type)) {
      return exitNumber == null
          ? 'Въезжайте на кольцо'
          : 'На кольце сверните на $exitNumber-й съезд';
    }
    if (type == 'uturn' || modifier == 'uturn') return 'Развернитесь';
    if (type == 'fork') {
      if (_isLeft(modifier)) return 'Держитесь левее';
      if (_isRight(modifier)) return 'Держитесь правее';
      return 'Продолжайте движение';
    }
    if (type == 'merge') {
      if (_isLeft(modifier)) return 'Влейтесь в поток слева';
      if (_isRight(modifier)) return 'Влейтесь в поток справа';
      return 'Влейтесь в поток';
    }
    if (type == 'on ramp' || type == 'onramp') return 'Выезжайте на съезд';
    if (type == 'off ramp' || type == 'offramp') return 'Сверните на съезд';
    if (type == 'continue' || type == 'new name') {
      return 'Продолжайте прямо';
    }
    if (type == 'turn' || type == 'end of road') {
      return _turnInstruction(modifier);
    }
    return 'Продолжайте движение';
  }

  static String _turnInstruction(String modifier) => switch (modifier) {
    'sharp left' => 'Резко поверните налево',
    'sharp right' => 'Резко поверните направо',
    'slight left' => 'Плавно поверните налево',
    'slight right' => 'Плавно поверните направо',
    'left' || 'keep left' => 'Поверните налево',
    'right' || 'keep right' => 'Поверните направо',
    'uturn' => 'Развернитесь',
    'straight' => 'Продолжайте прямо',
    _ => 'Продолжайте движение',
  };

  static NavigationManeuverIcon _icon({
    required String type,
    required String modifier,
  }) {
    if (type == 'arrive') return NavigationManeuverIcon.arrive;
    if (type == 'depart') return NavigationManeuverIcon.depart;
    if (_isRoundabout(type) ||
        type == 'exit roundabout' ||
        type == 'exit rotary') {
      return _isLeft(modifier)
          ? NavigationManeuverIcon.roundaboutLeft
          : NavigationManeuverIcon.roundaboutRight;
    }
    if (type == 'merge') return NavigationManeuverIcon.merge;
    if (type == 'fork') {
      return _isLeft(modifier)
          ? NavigationManeuverIcon.keepLeft
          : NavigationManeuverIcon.keepRight;
    }
    if (type == 'on ramp' ||
        type == 'onramp' ||
        type == 'off ramp' ||
        type == 'offramp') {
      return NavigationManeuverIcon.ramp;
    }
    if (type == 'uturn' || modifier == 'uturn') {
      return NavigationManeuverIcon.uTurn;
    }
    return switch (modifier) {
      'sharp left' => NavigationManeuverIcon.sharpLeft,
      'sharp right' => NavigationManeuverIcon.sharpRight,
      'slight left' => NavigationManeuverIcon.slightLeft,
      'slight right' => NavigationManeuverIcon.slightRight,
      'left' || 'keep left' => NavigationManeuverIcon.left,
      'right' || 'keep right' => NavigationManeuverIcon.right,
      _ => NavigationManeuverIcon.straight,
    };
  }

  static bool _isRoundabout(String type) =>
      type == 'roundabout' || type == 'rotary' || type == 'roundabout turn';

  static bool _isLeft(String modifier) => modifier.contains('left');

  static bool _isRight(String modifier) => modifier.contains('right');

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String _formatKilometers(double meters) {
    final value = (meters / 1000).toStringAsFixed(1);
    return (value.endsWith('.0') ? value.substring(0, value.length - 2) : value)
        .replaceAll('.', ',');
  }

  static String _metersWord(int value) {
    final mod100 = value.abs() % 100;
    final mod10 = value.abs() % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'метров';
    if (mod10 == 1) return 'метр';
    if (mod10 >= 2 && mod10 <= 4) return 'метра';
    return 'метров';
  }

  static String _kilometersWord(int value) {
    final mod100 = value.abs() % 100;
    final mod10 = value.abs() % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'километров';
    if (mod10 == 1) return 'километр';
    if (mod10 >= 2 && mod10 <= 4) return 'километра';
    return 'километров';
  }
}
