import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/widgets/delivery_details_view.dart';

Map<String, Object?> _payload(String? apartment) => buildOrderCreationPayload(
  serviceType: 'delivery',
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
  test('delivery payload includes apartment only when filled', () {
    expect(_payload(' 25 ')['destinationApartment'], '25');
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
