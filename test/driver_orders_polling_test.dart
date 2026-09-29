import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/screens/driver/driver_screen.dart';
import 'package:taxi_esil/services/driver_orders_poll_controller.dart';
import 'package:taxi_esil/services/order_offer_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/models/order_service_type.dart';
import 'package:taxi_esil/models/city.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/widgets/delivery_details_view.dart';
import 'package:taxi_esil/widgets/intercity_details_view.dart';

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(Duration.zero);
  }
}

Map<String, dynamic> order(String id) => {
  'id': id,
  'serviceType': 'city',
  'fromAddress': 'Pickup $id',
  'toAddress': 'Destination $id',
  'price': 700,
};

void main() {
  testWidgets('driver work city is persisted before orders are refreshed', (
    tester,
  ) async {
    String? updatedCity;
    var availableLoads = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DriverScreen(
          userId: 'driver-test',
          initialWorkCity: cityById('esil'),
          workCitiesLoader: () async => [cityById('esil'), cityById('rudny')],
          workCityUpdater: (cityId) async {
            updatedCity = cityId;
            return cityId;
          },
          activeOrderLoader: () async => null,
          availableOrdersLoader: () async {
            availableLoads++;
            return const [];
          },
        ),
      ),
    );
    await flush(tester);

    await tester.tap(find.byKey(const Key('driver_work_city_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Рудный'));
    await tester.pumpAndSettle();

    expect(updatedCity, 'rudny');
    expect(find.text('Рудный'), findsOneWidget);
    expect(availableLoads, greaterThanOrEqualTo(2));
  });

  for (final code in ['ru', 'kk', 'en']) {
    testWidgets(
      'driver delivery and intercity details use light text in $code',
      (tester) async {
        for (final serviceType in ['delivery', 'intercity']) {
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(code),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DriverScreen(
                key: ValueKey(serviceType),
                serviceType: serviceType == 'intercity'
                    ? OrderServiceType.intercity
                    : OrderServiceType.city,
                userId: 'driver-test',
                orderOfferService: _Offers(),
                activeOrderLoader: () async => null,
                availableOrdersLoader: () async => [
                  {
                    ...order('card-$serviceType'),
                    'serviceType': serviceType,
                    'delivery': {
                      'itemDescription': 'Documents',
                      'destinationApartment': '25',
                    },
                    'intercity': {'passengerCount': 2},
                  },
                ],
              ),
            ),
          );
          await flush(tester);
          if (serviceType == 'delivery') {
            expect(
              tester
                  .widget<DeliveryDetailsView>(find.byType(DeliveryDetailsView))
                  .onDarkCard,
              isTrue,
            );
          } else {
            expect(
              tester
                  .widget<IntercityDetailsView>(
                    find.byType(IntercityDetailsView),
                  )
                  .onDarkCard,
              isTrue,
            );
          }
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  test('new-order messages name both service types', () {
    expect(OrderServiceType.city.newDriverOrderMessage, 'Новый заказ — ТАКСИ');
    expect(
      OrderServiceType.delivery.newDriverOrderMessage,
      'Новый заказ — ДОСТАВКА',
    );
  });

  testWidgets('combined cards labelled; active order stops available polling', (
    tester,
  ) async {
    final active = StreamController<Map<String, dynamic>?>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DriverScreen(
          userId: 'driver-test',
          orderOfferService: _Offers(),
          activeOrdersStream: active.stream,
          availableOrdersLoader: () async {
            calls++;
            return [
              order('city'),
              {...order('delivery'), 'serviceType': 'delivery'},
            ];
          },
          activeOrderBuilder: (_) => const Scaffold(body: Text('active')),
        ),
      ),
    );
    active.add(null);
    await flush(tester);
    expect(find.text('ТАКСИ'), findsOneWidget);
    // Scroll if the second card is outside the viewport.
    await tester.scrollUntilVisible(
      find.text('ДОСТАВКА'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ДОСТАВКА'), findsOneWidget);
    active.add({
      'id': 'delivery',
      'status': 'accepted',
      'serviceType': 'delivery',
    });
    await flush(tester);
    final stoppedAt = calls;
    await tester.pump(const Duration(seconds: 6));
    expect(calls, stoppedAt);
    expect(find.text('active'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    unawaited(active.close());
  });
  testWidgets('HTTP 200 [] then orders update automatically without Retry', (
    tester,
  ) async {
    var requests = 0;
    final api = TulparApiClient(
      tokenProvider: () async => 'auth-test',
      client: MockClient((request) async {
        expectSync(request.url.path, '/api/orders/available');
        expectSync(request.url.queryParameters['serviceType'], 'city');
        final id = ++requests;
        return http.Response(
          jsonEncode(
            id == 1
                ? []
                : [
                    {
                      'id': 'order-$id',
                      'serviceType': 'city',
                      'pickupAddress': 'A',
                      'destinationAddress': 'B',
                      'passengerPrice': 700,
                    },
                  ],
          ),
          200,
        );
      }),
    );
    final poll = DriverOrdersPollController(
      label: 'available/test',
      load: () => api.getAvailableOrders(serviceType: 'city'),
    );
    poll.start();
    await flush(tester);
    expect(poll.value, isEmpty);
    expect(poll.error, isNull);
    await tester.pump(const Duration(seconds: 2));
    await flush(tester);
    expect(poll.value!.single['id'], 'order-2');
    await tester.pump(const Duration(seconds: 2));
    await flush(tester);
    expect(poll.value!.single['id'], 'order-3');
    expect(requests, 3);
    expect(poll.error, isNull);
    poll.dispose();
    api.close();
  });

  testWidgets('overlapping refresh and start never create a second request', (
    tester,
  ) async {
    var calls = 0;
    final response = Completer<List<String>>();
    final poll = DriverOrdersPollController(
      label: 'available/test',
      load: () {
        calls++;
        return response.future;
      },
    );
    poll.start();
    poll.start();
    await flush(tester);
    unawaited(poll.refresh());
    unawaited(poll.refresh());
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 1);
    response.complete(['one']);
    await flush(tester);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(calls, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await flush(tester);
    expect(calls, 2);
    poll.dispose();
  });

  testWidgets('transient failure retains data and next success clears error', (
    tester,
  ) async {
    var calls = 0;
    final poll = DriverOrdersPollController<List<String>>(
      label: 'available/test',
      load: () async {
        calls++;
        if (calls == 2) throw TimeoutException('temporary');
        return ['order-$calls'];
      },
    );
    poll.start();
    await flush(tester);
    await tester.pump(const Duration(seconds: 2));
    await flush(tester);
    expect(poll.error, isA<TimeoutException>());
    expect(poll.value, ['order-1']);
    await tester.pump(const Duration(seconds: 2));
    await flush(tester);
    expect(poll.value, ['order-3']);
    expect(poll.error, isNull);
    poll.dispose();
  });

  testWidgets(
    'stale in-flight response after stop is ignored before resuming',
    (tester) async {
      final response = Completer<List<String>>();
      var calls = 0;
      final poll = DriverOrdersPollController<List<String>>(
        label: 'available/test',
        load: () {
          return ++calls == 1 ? response.future : Future.value(['new']);
        },
      );
      poll.start();
      await flush(tester);
      poll.stop();
      poll.start();
      await flush(tester);
      expect(calls, 1); // No newer request can race the old one.
      response.complete(['stale']);
      await flush(tester);
      expect(poll.hasData, isFalse);
      expect(poll.error, isNull);
      await tester.pump(const Duration(seconds: 2));
      await flush(tester);
      expect(poll.value, ['new']);
      poll.dispose();
    },
  );

  testWidgets(
    'late response from disposed screen cannot overwrite new screen',
    (tester) async {
      final oldResponse = Completer<List<String>>();
      final old = DriverOrdersPollController(
        label: 'old',
        load: () => oldResponse.future,
      );
      old.start();
      await flush(tester);
      old.dispose();
      final next = DriverOrdersPollController(
        label: 'new',
        load: () async => ['new'],
      );
      next.start();
      await flush(tester);
      oldResponse.complete(['old']);
      await flush(tester);
      expect(old.hasData, isFalse);
      expect(next.value, ['new']);
      next.dispose();
    },
  );

  testWidgets('dispose stops requests; re-entry has exactly one loop', (
    tester,
  ) async {
    var calls = 0;
    Future<List<String>> load() async {
      calls++;
      return [];
    }

    final first = DriverOrdersPollController(label: 'first', load: load);
    first.start();
    await flush(tester);
    first.dispose();
    await tester.pump(const Duration(seconds: 20));
    expect(calls, 1);
    final next = DriverOrdersPollController(label: 'next', load: load);
    next.start();
    next.start();
    await flush(tester);
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 2));
    await flush(tester);
    expect(calls, 3);
    next.dispose();
  });

  testWidgets('available HTTP timeout aborts the underlying request', (
    tester,
  ) async {
    final client = _AbortClient();
    final api = TulparApiClient(
      client: client,
      tokenProvider: () async => 'auth-test',
    );
    Object? error;
    unawaited(
      api.getAvailableOrders().then<void>(
        (_) {},
        onError: (Object e) {
          error = e;
        },
      ),
    );
    await flush(tester);
    await tester.pump(const Duration(seconds: 8));
    await flush(tester);
    expect(error, isA<TimeoutException>());
    expect(client.aborted, isTrue);
    api.close();
  });

  testWidgets(
    'active endpoint error is separate and available list still updates',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DriverScreen(
            userId: 'driver-test',
            orderOfferService: _Offers(),
            activeOrderLoader: () async =>
                throw StateError('active endpoint failed'),
            availableOrdersLoader: () async => [order('order-${++calls}')],
          ),
        ),
      );
      await flush(tester);
      expect(
        find.byKey(const Key('driver_active_order_error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('driver_available_orders_error')),
        findsNothing,
      );
      expect(find.textContaining('Pickup order-1'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await flush(tester);
      expect(find.textContaining('Pickup order-2'), findsOneWidget);
      expect(
        find.byKey(const Key('driver_available_orders_error')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
    },
  );

  testWidgets(
    'screen retains order under transient banner, clears it automatically',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DriverScreen(
            userId: 'driver-test',
            orderOfferService: _Offers(),
            activeOrderLoader: () async => null,
            availableOrdersLoader: () async {
              if (++calls == 2) throw TimeoutException('temporary');
              return [order('order-$calls')];
            },
          ),
        ),
      );
      await flush(tester);
      await tester.pump(const Duration(seconds: 2));
      await flush(tester);
      expect(
        find.byKey(const Key('driver_available_orders_error')),
        findsOneWidget,
      );
      expect(find.textContaining('Pickup order-1'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await flush(tester);
      expect(
        find.byKey(const Key('driver_available_orders_error')),
        findsNothing,
      );
      expect(find.textContaining('Pickup order-3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
    },
  );

  testWidgets('covered route pauses; rebuild and re-entry keep one poll loop', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    var calls = 0;
    Future<List<Map<String, dynamic>>> load() async {
      calls++;
      return [];
    }

    Widget app() => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorKey: navigator,
      home: DriverScreen(
        userId: 'driver-test',
        activeOrderLoader: () async => null,
        availableOrdersLoader: load,
      ),
    );
    await tester.pumpWidget(app());
    await flush(tester);
    expect(calls, 1);
    await tester.pumpWidget(app());
    await flush(tester);
    expect(calls, 1);
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('covered')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pausedAt = calls;
    await tester.pump(const Duration(seconds: 10));
    await flush(tester);
    expect(calls, pausedAt);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(calls, pausedAt + 1);
    await tester.pump(const Duration(seconds: 2));
    await flush(tester);
    expect(calls, pausedAt + 2);
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
    final disposedAt = calls;
    await tester.pump(const Duration(seconds: 10));
    expect(calls, disposedAt);
  });
}

class _Offers extends OrderOfferService {
  @override
  Stream<DriverOffer?> watchOwnOffer(String orderId) => Stream.value(null);
}

class _AbortClient extends http.BaseClient {
  bool aborted = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final response = Completer<http.StreamedResponse>();
    (request as http.AbortableRequest).abortTrigger!.then((_) {
      aborted = true;
      response.completeError(http.RequestAbortedException(request.url));
    });
    return response.future;
  }
}
