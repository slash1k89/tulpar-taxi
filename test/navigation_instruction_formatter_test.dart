import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/models/navigation_step.dart';
import 'package:taxi_esil/utils/navigation_instruction_formatter.dart';

NavigationStep step({
  String type = 'turn',
  String modifier = 'straight',
  String street = 'ул. Абая',
  int? exitNumber,
}) => NavigationStep(
  type: type,
  modifier: modifier,
  targetLat: 51.95,
  targetLng: 66.40,
  streetName: street,
  exitNumber: exitNumber,
);

String instruction({
  String type = 'turn',
  String modifier = 'straight',
  int? exitNumber,
}) => NavigationInstructionFormatter.format(
  step(type: type, modifier: modifier, exitNumber: exitNumber),
).instruction;

void main() {
  group('Russian maneuver instructions', () {
    test('turn directions and intensity', () {
      expect(instruction(modifier: 'left'), 'Поверните налево');
      expect(instruction(modifier: 'right'), 'Поверните направо');
      expect(instruction(modifier: 'slight left'), 'Плавно поверните налево');
      expect(instruction(modifier: 'slight right'), 'Плавно поверните направо');
      expect(instruction(modifier: 'sharp left'), 'Резко поверните налево');
      expect(instruction(modifier: 'sharp right'), 'Резко поверните направо');
    });

    test('continue, fork, merge and ramps', () {
      expect(instruction(type: 'continue'), 'Продолжайте прямо');
      expect(instruction(type: 'fork', modifier: 'left'), 'Держитесь левее');
      expect(instruction(type: 'fork', modifier: 'right'), 'Держитесь правее');
      expect(
        instruction(type: 'merge', modifier: 'left'),
        'Влейтесь в поток слева',
      );
      expect(
        instruction(type: 'merge', modifier: 'right'),
        'Влейтесь в поток справа',
      );
      expect(instruction(type: 'on ramp'), 'Выезжайте на съезд');
      expect(instruction(type: 'off-ramp'), 'Сверните на съезд');
    });

    test('U-turn, roundabout, depart and arrive', () {
      expect(instruction(modifier: 'uturn'), 'Развернитесь');
      expect(
        instruction(type: 'roundabout', exitNumber: 2),
        'На кольце сверните на 2-й съезд',
      );
      expect(instruction(type: 'rotary'), 'Въезжайте на кольцо');
      expect(instruction(type: 'exit roundabout'), 'Съезжайте с кольца');
      expect(instruction(type: 'depart'), 'Начните движение');
      expect(instruction(type: 'arrive'), 'Вы прибыли');
    });

    test('unknown and missing modifier have stable fallbacks', () {
      expect(
        instruction(type: 'mystery', modifier: 'left'),
        'Продолжайте движение',
      );
      expect(instruction(modifier: ''), 'Продолжайте движение');
    });

    test('missing street is omitted', () {
      final presentation = NavigationInstructionFormatter.format(
        step(street: '  '),
      );
      expect(presentation.streetName, isNull);
    });
  });

  test('distance boundaries and invalid values are safe', () {
    String? format(double value) =>
        NavigationInstructionFormatter.formatDistancePrefix(value);

    expect(format(0), isNull);
    expect(format(24), isNull);
    expect(format(25), 'Через 30 м');
    expect(format(84), 'Через 80 м');
    expect(format(100), 'Через 100 м');
    expect(format(347), 'Через 350 м');
    expect(format(999), 'Через 1000 м');
    expect(format(1000), 'Через 1 км');
    expect(format(1240), 'Через 1,2 км');
    expect(format(-10), isNull);
    expect(format(double.nan), isNull);
    expect(format(double.infinity), isNull);
  });

  test('spoken distance uses natural Russian units', () {
    expect(
      NavigationInstructionFormatter.formatSpokenDistance(100),
      '100 метров',
    );
    expect(
      NavigationInstructionFormatter.formatSpokenDistance(1000),
      '1 километр',
    );
    expect(
      NavigationInstructionFormatter.formatSpokenDistance(1500),
      '1,5 километра',
    );
    expect(
      NavigationInstructionFormatter.formatSpokenDistance(2500),
      '2,5 километра',
    );
  });

  test('route summary is explicitly a static total', () {
    expect(
      NavigationInstructionFormatter.formatRouteSummary(
        distanceMeters: 6200,
        durationSeconds: 540,
      ),
      '6,2 км • 9 мин',
    );
    expect(
      NavigationInstructionFormatter.formatRouteSummary(
        distanceMeters: 0,
        durationSeconds: 540,
      ),
      isNull,
    );
  });
}
