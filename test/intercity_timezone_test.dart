import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/utils/intercity_ride_formatters.dart';
import 'package:taxi_esil/widgets/intercity_details_view.dart';

void main() {
  test('UTC timestamp is displayed as Kazakhstan UTC+5 civil time', () {
    final value = DateTime.parse('2026-08-28T02:00:00.000Z');

    expect(formatKazakhstanDateTime(value), '28.08.2026, 07:00');
    expect(formatIntercityRideDate(value), '28 августа');
    expect(formatIntercityRideTime(value), '07:00');
  });

  test('Kazakhstan conversion crosses midnight correctly', () {
    expect(
      formatKazakhstanDateTime(DateTime.parse('2026-08-28T21:30:00Z')),
      '29.08.2026, 02:30',
    );
  });

  test('Kazakhstan conversion crosses year boundary correctly', () {
    expect(
      formatKazakhstanDateTime(DateTime.parse('2026-12-31T21:30:00Z')),
      '01.01.2027, 02:30',
    );
  });

  test('ISO value carrying +05 offset is not offset twice', () {
    final value = DateTime.parse('2026-08-28T07:00:00+05:00');

    expect(formatKazakhstanDateTime(value), '28.08.2026, 07:00');
  });

  test('display conversion uses UTC calendar components, not toLocal', () {
    final source = DateTime.parse('2026-08-28T02:00:00Z');
    final display = toKazakhstanTime(source);

    expect(display.isUtc, isTrue);
    expect(
      [display.year, display.month, display.day, display.hour, display.minute],
      [2026, 8, 28, 7, 0],
    );
  });

  testWidgets('old INTERCITY scheduledAt uses Kazakhstan display policy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IntercityDetailsView(
            orderData: {
              'serviceType': 'intercity',
              'intercity': {'scheduledAt': '2026-08-28T02:00:00.000Z'},
            },
          ),
        ),
      ),
    );

    expect(find.text('28.08.2026, 07:00 · Время Казахстана'), findsOneWidget);
  });

  test('passenger and driver rideshare formatters share Kazakhstan policy', () {
    final departure = DateTime.parse('2026-08-28T21:30:00Z');

    expect(formatIntercityRideDate(departure), '29 августа');
    expect(formatIntercityRideTime(departure), '02:30');
  });
}
