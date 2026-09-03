import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/models/intercity_ride_request.dart';
import 'package:taxi_esil/models/intercity_pickup_draft.dart';
import 'package:taxi_esil/services/intercity_ride_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

void main() {
  test('search uses the passenger rides API contract', () async {
    late http.Request captured;
    final service = _service((request) async {
      captured = request;
      return _json(200, {
        'rides': [_rideJson()],
      });
    });

    final rides = await service.searchRides(
      originCity: ' Есиль ',
      destinationCity: ' Астана ',
      travelDate: DateTime(2026, 9, 3),
      seats: 2,
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/intercity-rides/search');
    expect(captured.url.queryParameters, {
      'originCity': 'Есиль',
      'destinationCity': 'Астана',
      'travelDate': '2026-09-03',
      'seats': '2',
    });
    expect(captured.headers['Authorization'], 'Bearer test-token');
    expect(rides.single.pricePerSeat, 4000);
    expect(rides.single.availableSeats, 3);
  });

  test('booking sends only seats and stable clientRequestId', () async {
    final requests = <http.Request>[];
    var responseCode = 201;
    final service = _service((request) async {
      requests.add(request);
      return _json(responseCode, {'booking': _bookingJson()});
    });
    const clientRequestId = '00000000-0000-4000-8000-000000000001';

    final created = await service.bookRide(
      rideId: 'ride-1',
      seats: 2,
      clientRequestId: clientRequestId,
    );
    responseCode = 200;
    final replay = await service.bookRide(
      rideId: 'ride-1',
      seats: 2,
      clientRequestId: clientRequestId,
    );

    expect(created.bookingId, 'booking-1');
    expect(replay.bookingId, created.bookingId);
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/intercity-rides/ride-1/book');
      expect(jsonDecode(request.body), {
        'seats': 2,
        'clientRequestId': clientRequestId,
      });
    }
  });

  test('booking conflict remains a typed 409 error', () async {
    final service = _service(
      (_) async => _json(409, {'error': 'Not enough available seats'}),
    );

    await expectLater(
      service.bookRide(
        rideId: 'ride-1',
        seats: 7,
        clientRequestId: '00000000-0000-4000-8000-000000000002',
      ),
      throwsA(
        isA<TulparApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          409,
        ),
      ),
    );
  });

  test(
    'booking and request serialize pickup and trim optional comment',
    () async {
      final requests = <http.Request>[];
      final service = _service((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/book')) {
          return _json(201, {'booking': _bookingJson()});
        }
        return _json(201, {'request': _requestJson()});
      });
      const pickup = IntercityPickupDraft(
        address: ' ул. Абая, 15 ',
        latitude: 51.95,
        longitude: 66.40,
        passengerComment: '  Главный вход  ',
      );

      await service.bookRide(
        rideId: 'ride-1',
        seats: 2,
        clientRequestId: '00000000-0000-4000-8000-000000000003',
        pickup: pickup,
      );
      await service.createRequest(
        originCity: 'Есиль',
        destinationCity: 'Астана',
        travelDate: DateTime(2026, 9, 4),
        seats: 2,
        pickup: pickup.copyWith(passengerComment: '   '),
      );

      expect(jsonDecode(requests[0].body), {
        'seats': 2,
        'clientRequestId': '00000000-0000-4000-8000-000000000003',
        'pickupAddress': 'ул. Абая, 15',
        'pickupLat': 51.95,
        'pickupLng': 66.40,
        'passengerComment': 'Главный вход',
      });
      expect(jsonDecode(requests[1].body), {
        'originCity': 'Есиль',
        'destinationCity': 'Астана',
        'travelDate': '2026-09-04',
        'seats': 2,
        'pickupAddress': 'ул. Абая, 15',
        'pickupLat': 51.95,
        'pickupLng': 66.40,
      });
    },
  );

  test('request endpoints use public fields and keep matches active', () async {
    final requests = <http.Request>[];
    final service = _service((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/cancel')) {
        return _json(200, {'request': _requestJson(status: 'cancelled')});
      }
      if (request.method == 'GET') {
        return _json(200, {
          'requests': [_requestJson()],
        });
      }
      return _json(201, {'request': _requestJson()});
    });

    final created = await service.createRequest(
      originCity: 'Есиль',
      destinationCity: 'Астана',
      travelDate: DateTime(2026, 9, 4),
      seats: 2,
    );
    final mine = await service.getMyRequests();
    final cancelled = await service.cancelRequest(created.requestId);

    expect(created.status, IntercityRideRequestStatus.active);
    expect(created.matchedRideIds, ['ride-1', 'ride-2']);
    expect(mine.single.requestId, created.requestId);
    expect(cancelled.status, IntercityRideRequestStatus.cancelled);
    expect(jsonDecode(requests.first.body), {
      'originCity': 'Есиль',
      'destinationCity': 'Астана',
      'travelDate': '2026-09-04',
      'seats': 2,
    });
    expect(requests.map((request) => request.url.path), [
      '/api/intercity-rides/requests',
      '/api/intercity-rides/requests/mine',
      '/api/intercity-rides/requests/request-1/cancel',
    ]);
  });

  test('idempotent booking cancellation with 200 is success', () async {
    var calls = 0;
    final service = _service((request) async {
      calls += 1;
      return _json(200, {'booking': _bookingJson(status: 'cancelled')});
    });

    final first = await service.cancelBooking('booking-1');
    final replay = await service.cancelBooking('booking-1');

    expect(calls, 2);
    expect(first.status.name, 'cancelled');
    expect(replay.status, first.status);
  });
}

IntercityRideService _service(
  Future<http.Response> Function(http.Request request) handler,
) => IntercityRideService(
  apiClient: TulparApiClient(
    client: MockClient(handler),
    tokenProvider: () async => 'test-token',
  ),
);

http.Response _json(int status, Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _rideJson() => {
  'rideId': 'ride-1',
  'originCity': 'Есиль',
  'originLat': 51.95,
  'originLng': 66.40,
  'destinationCity': 'Астана',
  'destinationLat': 51.16,
  'destinationLng': 71.47,
  'departureAt': '2026-09-03T07:00:00.000Z',
  'totalSeats': 4,
  'availableSeats': 3,
  'pricePerSeat': 4000,
  'allowsLuggage': true,
  'status': 'scheduled',
  'driver': {'name': 'Тест', 'carModel': 'Sedan', 'carColor': 'Белый'},
};

Map<String, dynamic> _bookingJson({String status = 'confirmed'}) => {
  'bookingId': 'booking-1',
  'rideId': 'ride-1',
  'seats': 2,
  'pricePerSeat': 4000,
  'totalPrice': 8000,
  'status': status,
  'route': {'originCity': 'Есиль', 'destinationCity': 'Астана'},
  'departureAt': '2026-09-03T07:00:00.000Z',
  'rideStatus': 'scheduled',
};

Map<String, dynamic> _requestJson({String status = 'active'}) => {
  'requestId': 'request-1',
  'originCity': 'Есиль',
  'destinationCity': 'Астана',
  'travelDate': '2026-09-04',
  'seats': 2,
  'status': status,
  'matchedRideIds': ['ride-1', 'ride-2'],
  // These internal fields must not become fields of the Flutter DTO.
  'passengerId': 'internal-user-id',
  'firebaseUid': 'internal-firebase-uid',
  'pushToken': 'internal-push-token',
};
