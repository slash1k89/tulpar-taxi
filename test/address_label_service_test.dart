import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/address_label_service.dart';
import 'package:taxi_esil/widgets/order_stops_view.dart';

void main() {
  test('RU keeps the canonical Cyrillic address unchanged', () {
    expect(
      AddressLabelService.format('улица Мырзашева, 66А', const Locale('ru')),
      'улица Мырзашева, 66А',
    );
  });

  test('KK uses canonical address when a separate Kazakh value is absent', () {
    expect(
      AddressLabelService.format(
        'улица Тын Игерушилер, 12',
        const Locale('kk'),
      ),
      'улица Тын Игерушилер, 12',
    );
  });

  test('EN prefers name_en and preserves already Latin geocoder names', () {
    expect(
      AddressLabelService.format({
        'name': 'Вокзал',
        'name_en': 'Esil Railway Station',
      }, const Locale('en')),
      'Esil Railway Station',
    );
    expect(
      AddressLabelService.format('Abai Street, 10', const Locale('en')),
      'Abai Street, 10',
    );
    expect(
      AddressLabelService.format({
        'address': 'улица Абая, 10',
        'name': 'Abai Street',
      }, const Locale('en')),
      'Abai Street',
    );
  });

  test('EN transliterates Cyrillic fallback and preserves house number', () {
    final label = AddressLabelService.format(
      'улица Мырзашева, 66/1',
      const Locale('en'),
    );
    expect(label, 'ulitsa Myrzasheva, 66/1');
    expect(label, isNot(matches(RegExp(r'[\u0400-\u04FF]'))));
  });

  test(
    'known Tulpar POI uses an English meaning instead of transliteration',
    () {
      expect(
        AddressLabelService.format(
          'Железнодорожный вокзал Есиль',
          const Locale('en'),
        ),
        'Railway Station Esil',
      );
      expect(
        AddressLabelService.format('Районная больница', const Locale('en')),
        'District Hospital',
      );
    },
  );

  test('order field prefers explicit English address variant', () {
    expect(
      AddressLabelService.fromOrder(
        {
          'toAddress': 'улица Абая, 10',
          'destinationAddressEn': 'Abai Street, 10',
        },
        const Locale('en'),
        const ['toAddress', 'destinationAddress'],
      ),
      'Abai Street, 10',
    );
  });

  testWidgets('multi-stop view formats every point with the same locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: Scaffold(
          body: OrderStopsView(
            orderData: {
              'fromAddress': 'улица Абая, 1',
              'stops': [
                {
                  'address': 'Железнодорожный вокзал Есиль',
                  'address_en': 'Esil Railway Station',
                },
                {'address': 'улица Мырзашева, 66А'},
              ],
            },
          ),
        ),
      ),
    );

    expect(find.text('ulitsa Abaya, 1'), findsOneWidget);
    expect(find.text('Esil Railway Station'), findsOneWidget);
    expect(find.text('ulitsa Myrzasheva, 66A'), findsOneWidget);
  });
}
