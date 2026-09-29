import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/services/order_creation_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/widgets/order_creation_error_snackbar.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';

void main() {
  test('city order API payload carries the selected city', () {
    final payload = buildOrderCreationPayload(
      serviceType: 'city',
      cityId: 'arkalyk',
      passengerPrice: 800,
      pickupAddress: 'A',
      destinationAddress: 'B',
      pickupLat: 50.25,
      pickupLng: 66.91,
      destinationLat: 50.26,
      destinationLng: 66.92,
    );
    expect(payload['cityId'], 'arkalyk');
  });
  const from = LatLng(51.957, 66.404);
  const to = LatLng(51.969, 66.421);

  test('correct order is validated, serialized and submitted', () async {
    final gateway = _RecordingOrderGateway();
    final service = OrderCreationService(gateway: gateway);

    final orderId = await service.createOrder(
      fromAddress: '  Улица А, 1  ',
      toAddress: 'Улица Б, 2',
      price: 750,
      fromPoint: from,
      toPoint: to,
      cityId: 'esil',
    );

    expect(orderId, 'order-1');
    expect(gateway.calls, 1);
    expect(gateway.lastDraft?.cityId, 'esil');

    final fields = gateway.lastDraft!.toFirestore(
      passengerId: 'firebase-uid',
      createdAt: 'server-timestamp',
    );
    expect(fields, {
      'passengerId': 'firebase-uid',
      'fromAddress': 'Улица А, 1',
      'toAddress': 'Улица Б, 2',
      'price': 750,
      'passengerPrice': 750,
      'agreedPrice': null,
      'fromLat': 51.957,
      'fromLng': 66.404,
      'toLat': 51.969,
      'toLng': 66.421,
      'status': 'searching',
      'createdAt': 'server-timestamp',
    });
    expect(fields.containsKey('cityId'), isFalse);
  });

  testWidgets('order creation failure shows a short understandable message', (
    tester,
  ) async {
    const error = OrderCreationException(
      OrderCreationFailure.permissionDenied,
      'Не удалось создать заказ. Проверьте вход в аккаунт.',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showOrderCreationError(context, error),
              child: const Text('Создать'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Создать'));
    await tester.pump();

    expect(find.text('Нет доступа к созданию заказа.'), findsOneWidget);
    expect(find.textContaining('converted Future'), findsNothing);
  });

  test('active-order failure preserves the binding id for safe recovery', () {
    const error = OrderCreationException(
      OrderCreationFailure.activeOrderExists,
      'У вас уже есть активный заказ. Открываем его.',
      activeOrderId: 'active-order-1',
    );

    expect(error.activeOrderId, 'active-order-1');
  });

  test('delivery draft keeps delivery fields and skips city minimum', () async {
    final gateway = _RecordingOrderGateway();
    final service = OrderCreationService(gateway: gateway);

    await service.createOrder(
      fromAddress: 'Пункт забора',
      toAddress: 'Пункт доставки',
      price: 300,
      fromPoint: from,
      toPoint: to,
      cityId: 'esil',
      serviceType: 'delivery',
      delivery: const DeliveryOrderDetails(
        itemDescription: 'Документы',
        recipientName: 'Алия',
        recipientPhone: '+7 700 000 00 00',
        destinationApartment: '25',
      ),
    );

    expect(gateway.lastDraft?.serviceType, 'delivery');
    expect(gateway.lastDraft?.delivery?.itemDescription, 'Документы');
    expect(gateway.lastDraft?.delivery?.recipientName, 'Алия');
    expect(gateway.lastDraft?.delivery?.recipientPhone, '+7 700 000 00 00');
    expect(gateway.lastDraft?.delivery?.destinationApartment, '25');
    expect(
      gateway.lastDraft?.delivery?.normalizedRecipientPhone,
      '+77000000000',
    );
  });

  test('delivery rejects an incomplete recipient phone', () {
    const details = DeliveryOrderDetails(
      itemDescription: 'Документы',
      recipientName: 'Алия',
      recipientPhone: '+7 (700) 123-45',
    );

    expect(details.validate, throwsA(isA<OrderCreationException>()));
  });

  test('delivery requires parcel and recipient details', () {
    const draft = OrderDraft(
      fromAddress: 'Пункт забора',
      toAddress: 'Пункт доставки',
      price: 300,
      fromPoint: from,
      toPoint: to,
      cityId: 'esil',
      serviceType: 'delivery',
      delivery: DeliveryOrderDetails(
        itemDescription: '',
        recipientName: 'Алия',
        recipientPhone: '+7 700 000 00 00',
      ),
    );

    expect(
      draft.validate,
      throwsA(
        isA<OrderCreationException>().having(
          (error) => error.failure,
          'failure',
          OrderCreationFailure.invalidData,
        ),
      ),
    );
  });

  testWidgets('repeated taps share one in-flight creation', (tester) async {
    final gateway = _CompletingOrderGateway();
    final service = OrderCreationService(gateway: gateway);
    final results = <Future<String>>[];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ElevatedButton(
            onPressed: () {
              results.add(
                service.createOrder(
                  fromAddress: 'Точка А',
                  toAddress: 'Точка Б',
                  price: 800,
                  fromPoint: from,
                  toPoint: to,
                  cityId: 'esil',
                ),
              );
            },
            child: const Text('Создать заказ'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Создать заказ'));
    await tester.tap(find.text('Создать заказ'));

    expect(results, hasLength(2));
    expect(identical(results[0], results[1]), isTrue);
    expect(gateway.calls, 1);

    gateway.completer.complete('order-1');
    expect(await results[0], 'order-1');
    expect(await results[1], 'order-1');
    expect(gateway.calls, 1);
  });
}

class _RecordingOrderGateway implements OrderCreationGateway {
  int calls = 0;
  OrderDraft? lastDraft;

  @override
  Future<String> create(OrderDraft draft) async {
    calls++;
    lastDraft = draft;
    return 'order-1';
  }
}

class _CompletingOrderGateway implements OrderCreationGateway {
  final completer = Completer<String>();
  int calls = 0;

  @override
  Future<String> create(OrderDraft draft) {
    calls++;
    return completer.future;
  }
}
