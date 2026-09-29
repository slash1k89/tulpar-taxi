import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/widgets/delivery_details_view.dart';

Map<String, Object?> _payload(String? apartment) => buildOrderCreationPayload(
  serviceType: 'delivery',
  cityId: 'rudny',
  passengerPrice: 1000,
  pickupAddress: 'Абая, 1',
  destinationAddress: 'Ауэзова, 2',
  pickupLat: 51.95,
  pickupLng: 66.40,
  destinationLat: 51.96,
  destinationLng: 66.41,
  itemDescription: 'Документы',
  recipientName: 'Андрей',
  recipientPhone: '+77777777777',
  destinationApartment: apartment,
);

void main() {
  for (final code in ['ru', 'kk', 'en']) {
    testWidgets('delivery card on dark surface stays readable in $code', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ColoredBox(
              color: const Color(0xFF1E1E1E),
              child: DeliveryDetailsView(
                onDarkCard: true,
                orderData: {
                  'serviceType': 'delivery',
                  'delivery': {
                    'itemDescription': 'Documents',
                    'recipientName': 'Sam',
                    'destinationApartment': '25',
                  },
                },
              ),
            ),
          ),
        ),
      );
      final texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(DeliveryDetailsView),
          matching: find.byType(Text),
        ),
      );
      expect(texts, isNotEmpty);
      expect(
        texts.every(
          (text) =>
              text.style?.color == Colors.white ||
              text.style?.color == Colors.white70,
        ),
        isTrue,
      );
    });
  }
  test('delivery payload includes apartment only when filled', () {
    expect(_payload(' 25 ')['destinationApartment'], '25');
    expect(_payload(' 25 ')['cityId'], 'rudny');
    expect(_payload('').containsKey('destinationApartment'), isFalse);
    expect(_payload(null).containsKey('destinationApartment'), isFalse);
  });

  test('delivery normalization accepts PostgreSQL snake case', () {
    final delivery = normalizeDeliveryData({
      'item_description': 'Документы',
      'recipient_name': 'Андрей',
      'recipient_phone': '+77777777777',
      'destination_apartment': '25',
    });
    expect(delivery?['destinationApartment'], '25');
  });

  testWidgets('delivery details show apartment only when present', (
    tester,
  ) async {
    Future<void> pump(String? apartment) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DeliveryDetailsView(
            orderData: {
              'serviceType': 'delivery',
              'delivery': {
                'recipientName': 'Андрей',
                'recipientPhone': '+77777777777',
                'destinationApartment': apartment ?? '',
              },
            },
          ),
        ),
      ),
    );

    await pump('25');
    expect(find.text('Квартира: 25'), findsOneWidget);
    await pump(null);
    expect(find.textContaining('Квартира:'), findsNothing);
  });
}
