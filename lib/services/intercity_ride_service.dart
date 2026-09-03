import 'dart:math';

import '../models/intercity_ride.dart';
import '../models/intercity_ride_booking.dart';
import '../models/intercity_driver_ride_draft.dart';
import '../models/intercity_pickup_draft.dart';
import '../models/intercity_ride_request.dart';
import 'tulpar_api_client.dart';

abstract interface class IntercityRideRepository {
  String createClientRequestId();

  Future<List<IntercityRide>> searchRides({
    required String originCity,
    required String destinationCity,
    required DateTime travelDate,
    required int seats,
  });

  Future<IntercityRide> getRide(String rideId);

  Future<IntercityRideBooking> bookRide({
    required String rideId,
    required int seats,
    required String clientRequestId,
    IntercityPickupDraft? pickup,
  });

  Future<List<IntercityRideBooking>> getMyBookings();

  Future<IntercityRideBooking> cancelBooking(String bookingId);

  Future<IntercityRideRequest> createRequest({
    required String originCity,
    required String destinationCity,
    required DateTime travelDate,
    required int seats,
    IntercityPickupDraft? pickup,
  });

  Future<List<IntercityRideRequest>> getMyRequests();

  Future<IntercityRideRequest> cancelRequest(String requestId);
}

abstract interface class IntercityDriverRideRepository {
  Future<IntercityRide> createDriverRide(IntercityDriverRideDraft draft);

  Future<List<IntercityRide>> getMyDriverRides();

  Future<IntercityRide> getDriverRide(String rideId);

  Future<List<IntercityRideBooking>> getDriverRideBookings(String rideId);

  Future<IntercityRide> updateDriverRide({
    required String rideId,
    required IntercityDriverRideDraft draft,
    required bool hasConfirmedBooking,
  });

  Future<IntercityRide> cancelDriverRide(String rideId);

  Future<IntercityRide> departDriverRide(String rideId);

  Future<IntercityRide> completeDriverRide(String rideId);
}

class IntercityRideService
    implements IntercityRideRepository, IntercityDriverRideRepository {
  IntercityRideService({TulparApiClient? apiClient, Random? random})
    : _apiClient = apiClient ?? TulparApiClient(),
      _random = random ?? Random.secure();

  final TulparApiClient _apiClient;
  final Random _random;

  @override
  String createClientRequestId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final value = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final hex = value.join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  @override
  Future<List<IntercityRide>> searchRides({
    required String originCity,
    required String destinationCity,
    required DateTime travelDate,
    required int seats,
  }) async {
    final response = await _apiClient.searchIntercityRides(
      originCity: originCity,
      destinationCity: destinationCity,
      travelDate: formatIntercityApiDate(travelDate),
      seats: seats,
    );
    return _rideList(response['rides']);
  }

  @override
  Future<IntercityRide> getRide(String rideId) async {
    final response = await _apiClient.getIntercityRide(rideId);
    return _ride(response['ride'], 'Поездка не найдена');
  }

  @override
  Future<IntercityRideBooking> bookRide({
    required String rideId,
    required int seats,
    required String clientRequestId,
    IntercityPickupDraft? pickup,
  }) async {
    final response = await _apiClient.bookIntercityRide(
      rideId: rideId,
      seats: seats,
      clientRequestId: clientRequestId,
      pickupAddress: pickup?.address,
      pickupLat: pickup?.latitude,
      pickupLng: pickup?.longitude,
      passengerComment: pickup?.passengerComment,
    );
    return _booking(response['booking'], 'Бронь не найдена');
  }

  @override
  Future<List<IntercityRideBooking>> getMyBookings() async {
    final response = await _apiClient.getMyIntercityBookings();
    final raw = response['bookings'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => IntercityRideBooking.fromJson(Map.from(item)))
        .toList(growable: false);
  }

  @override
  Future<IntercityRideBooking> cancelBooking(String bookingId) async {
    final response = await _apiClient.cancelIntercityBooking(bookingId);
    return _booking(response['booking'], 'Бронь не найдена');
  }

  @override
  Future<IntercityRideRequest> createRequest({
    required String originCity,
    required String destinationCity,
    required DateTime travelDate,
    required int seats,
    IntercityPickupDraft? pickup,
  }) async {
    final response = await _apiClient.createIntercityRideRequest(
      originCity: originCity,
      destinationCity: destinationCity,
      travelDate: formatIntercityApiDate(travelDate),
      seats: seats,
      pickupAddress: pickup?.address,
      pickupLat: pickup?.latitude,
      pickupLng: pickup?.longitude,
      passengerComment: pickup?.passengerComment,
    );
    return _request(response['request'], 'Заявка не найдена');
  }

  @override
  Future<List<IntercityRideRequest>> getMyRequests() async {
    final response = await _apiClient.getMyIntercityRideRequests();
    final raw = response['requests'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => IntercityRideRequest.fromJson(Map.from(item)))
        .toList(growable: false);
  }

  @override
  Future<IntercityRideRequest> cancelRequest(String requestId) async {
    final response = await _apiClient.cancelIntercityRideRequest(requestId);
    return _request(response['request'], 'Заявка не найдена');
  }

  @override
  Future<IntercityRide> createDriverRide(IntercityDriverRideDraft draft) async {
    final response = await _apiClient.createIntercityDriverRide(
      draft.toCreateJson(),
    );
    return _ride(response['ride'], 'Поездка не создана');
  }

  @override
  Future<List<IntercityRide>> getMyDriverRides() async {
    final response = await _apiClient.getMyIntercityDriverRides();
    return _rideList(response['rides']);
  }

  @override
  Future<IntercityRide> getDriverRide(String rideId) => getRide(rideId);

  @override
  Future<List<IntercityRideBooking>> getDriverRideBookings(
    String rideId,
  ) async {
    final response = await _apiClient.getIntercityDriverRideBookings(rideId);
    final raw = response['bookings'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => IntercityRideBooking.fromJson(Map.from(item)))
        .toList(growable: false);
  }

  @override
  Future<IntercityRide> updateDriverRide({
    required String rideId,
    required IntercityDriverRideDraft draft,
    required bool hasConfirmedBooking,
  }) async {
    final response = await _apiClient.updateIntercityDriverRide(
      rideId: rideId,
      body: draft.toPatchJson(hasConfirmedBooking: hasConfirmedBooking),
    );
    return _ride(response['ride'], 'Поездка не найдена');
  }

  @override
  Future<IntercityRide> cancelDriverRide(String rideId) async {
    final response = await _apiClient.cancelIntercityDriverRide(rideId);
    return _ride(response['ride'], 'Поездка не найдена');
  }

  @override
  Future<IntercityRide> departDriverRide(String rideId) async {
    final response = await _apiClient.departIntercityDriverRide(rideId);
    return _ride(response['ride'], 'Поездка не найдена');
  }

  @override
  Future<IntercityRide> completeDriverRide(String rideId) async {
    final response = await _apiClient.completeIntercityDriverRide(rideId);
    return _ride(response['ride'], 'Поездка не найдена');
  }

  List<IntercityRide> _rideList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => IntercityRide.fromJson(Map.from(item)))
        .toList(growable: false);
  }

  IntercityRide _ride(Object? raw, String message) {
    if (raw is! Map) throw TulparApiException(502, message);
    return IntercityRide.fromJson(Map.from(raw));
  }

  IntercityRideBooking _booking(Object? raw, String message) {
    if (raw is! Map) throw TulparApiException(502, message);
    return IntercityRideBooking.fromJson(Map.from(raw));
  }

  IntercityRideRequest _request(Object? raw, String message) {
    if (raw is! Map) throw TulparApiException(502, message);
    return IntercityRideRequest.fromJson(Map.from(raw));
  }
}

String formatIntercityApiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
