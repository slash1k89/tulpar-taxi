import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/models/intercity_driver_ride_draft.dart';
import 'package:taxi_esil/services/intercity_ride_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

void main() {
  test('driver create sends only backend-approved fields', () async {
    late http.Request captured;
    final service = _service((request) async {
      captured = request;
      return _json(201, {'ride': _rideJson()});
    });

    final ride = await service.createDriverRide(_draft);

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/intercity-rides');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body, _draft.toCreateJson());
    expect(
      body.keys,
      isNot(containsAll(['driverId', 'availableSeats', 'status'])),
    );
    expect(ride.rideId, 'ride-1');
  });

  test('mine and owner bookings parse only public driver DTO', () async {
    final service = _service((request) async {
      if (request.url.path.endsWith('/bookings')) {
        return _json(200, {
          'bookings': [_bookingJson()],
        });
      }
      return _json(200, {
        'rides': [_rideJson()],
      });
    });

    final rides = await service.getMyDriverRides();
    final bookings = await service.getDriverRideBookings('ride-1');

    expect(rides.single.availableSeats, 2);
    expect(bookings.single.passenger?.name, 'Тестовый пассажир');
    expect(bookings.single.passenger?.phone, '+7 700 000 00 00');
    expect(bookings.single.totalPrice, 8000);
  });

  test('protected patch contains only mutable post-booking fields', () async {
    late Map<String, dynamic> captured;
    final service = _service((request) async {
      captured = jsonDecode(request.body) as Map<String, dynamic>;
      return _json(200, {'ride': _rideJson(pricePerSeat: 5000)});
    });

    final updated = await service.updateDriverRide(
      rideId: 'ride-1',
      draft: _draft,
      hasConfirmedBooking: true,
    );

    expect(captured, {
      'pricePerSeat': 4000,
      'allowsLuggage': true,
      'comment': 'Тестовая поездка',
    });
    expect(captured.containsKey('departureAt'), isFalse);
    expect(captured.containsKey('totalSeats'), isFalse);
    expect(updated.pricePerSeat, 5000);
  });

  test('unbooked patch may update route departure and inventory', () {
    final body = _draft.toPatchJson(hasConfirmedBooking: false);

    expect(body['originCity'], 'Есиль');
    expect(body['destinationCity'], 'Астана');
    expect(body['departureAt'], '2030-09-03T07:00:00.000Z');
    expect(body['totalSeats'], 4);
    expect(body.containsKey('availableSeats'), isFalse);
  });

  test('cancel depart complete use exact lifecycle endpoints', () async {
    final paths = <String>[];
    final service = _service((request) async {
      paths.add(request.url.path);
      final status = request.url.path.endsWith('/cancel')
          ? 'cancelled'
          : request.url.path.endsWith('/depart')
          ? 'departed'
          : 'completed';
      return _json(200, {'ride': _rideJson(status: status)});
    });

    await service.cancelDriverRide('ride-1');
    await service.departDriverRide('ride-1');
    await service.completeDriverRide('ride-1');

    expect(paths, [
      '/api/intercity-rides/ride-1/cancel',
      '/api/intercity-rides/ride-1/depart',
      '/api/intercity-rides/ride-1/complete',
    ]);
  });
}

final _draft = IntercityDriverRideDraft(
  originCity: 'Есиль',
  originLat: 51.95,
  originLng: 66.40,
  destinationCity: 'Астана',
  destinationLat: 51.16,
  destinationLng: 71.47,
  departureAt: DateTime.utc(2030, 9, 3, 7),
  totalSeats: 4,
  pricePerSeat: 4000,
  allowsLuggage: true,
  comment: ' Тестовая поездка ',
);

IntercityRideService _service(
  Future<http.Response> Function(http.Request request) handler,
) => IntercityRideService(
  apiClient: TulparApiClient(
    client: MockClient(handler),
    tokenProvider: () async => 'driver-test-token',
  ),
);

http.Response _json(int status, Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _rideJson({
  String status = 'scheduled',
  int pricePerSeat = 4000,
}) => {
  'rideId': 'ride-1',
  'originCity': 'Есиль',
  'originLat': 51.95,
  'originLng': 66.40,
  'destinationCity': 'Астана',
  'destinationLat': 51.16,
  'destinationLng': 71.47,
  'departureAt': '2030-09-03T07:00:00.000Z',
  'totalSeats': 4,
  'availableSeats': 2,
  'pricePerSeat': pricePerSeat,
  'allowsLuggage': true,
  'comment': 'Тестовая поездка',
  'status': status,
  'driver': {'name': 'Водитель', 'carModel': 'Sedan', 'carColor': 'Белый'},
};

Map<String, dynamic> _bookingJson() => {
  'bookingId': 'booking-1',
  'rideId': 'ride-1',
  'seats': 2,
  'pricePerSeat': 4000,
  'totalPrice': 8000,
  'status': 'confirmed',
  'route': {'originCity': 'Есиль', 'destinationCity': 'Астана'},
  'departureAt': '2030-09-03T07:00:00.000Z',
  'rideStatus': 'scheduled',
  'passenger': {
    'name': 'Тестовый пассажир',
    'phone': '+7 700 000 00 00',
    'firebaseUid': 'must-be-ignored',
  },
};
