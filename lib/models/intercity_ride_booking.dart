import 'intercity_ride_json.dart';
import 'intercity_pickup_draft.dart';

enum IntercityRideBookingStatus { confirmed, cancelled, completed, unknown }

class IntercityBookingRoute {
  const IntercityBookingRoute({
    required this.originCity,
    required this.destinationCity,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
  });

  final String originCity;
  final double? originLat;
  final double? originLng;
  final String destinationCity;
  final double? destinationLat;
  final double? destinationLng;

  factory IntercityBookingRoute.fromJson(Map<String, dynamic> json) =>
      IntercityBookingRoute(
        originCity: intercityString(json['originCity']),
        originLat: intercityDouble(json['originLat']),
        originLng: intercityDouble(json['originLng']),
        destinationCity: intercityString(json['destinationCity']),
        destinationLat: intercityDouble(json['destinationLat']),
        destinationLng: intercityDouble(json['destinationLng']),
      );
}

class IntercityBookingDriver {
  const IntercityBookingDriver({
    this.name,
    this.carModel,
    this.carColor,
    this.carNumber,
    this.phone,
  });

  final String? name;
  final String? carModel;
  final String? carColor;
  final String? carNumber;
  final String? phone;

  factory IntercityBookingDriver.fromJson(Map<String, dynamic> json) =>
      IntercityBookingDriver(
        name: _nullableText(json['name']),
        carModel: _nullableText(json['carModel']),
        carColor: _nullableText(json['carColor']),
        carNumber: _nullableText(json['carNumber']),
        phone: _nullableText(json['phone']),
      );
}

class IntercityBookingPassenger {
  const IntercityBookingPassenger({this.name, this.phone});

  final String? name;
  final String? phone;

  factory IntercityBookingPassenger.fromJson(Map<String, dynamic> json) =>
      IntercityBookingPassenger(
        name: _nullableText(json['name']),
        phone: _nullableText(json['phone']),
      );
}

class IntercityRideBooking {
  const IntercityRideBooking({
    required this.bookingId,
    required this.rideId,
    required this.seats,
    required this.pricePerSeat,
    required this.totalPrice,
    required this.status,
    required this.route,
    required this.rideStatus,
    this.departureAt,
    this.driver,
    this.passenger,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.passengerComment,
    this.pickupReachedAt,
    this.createdAt,
    this.updatedAt,
    this.chatAvailable = false,
  });

  final String bookingId;
  final String rideId;
  final int seats;
  final int pricePerSeat;
  final int totalPrice;
  final IntercityRideBookingStatus status;
  final IntercityBookingRoute route;
  final DateTime? departureAt;
  final String rideStatus;
  final IntercityBookingDriver? driver;
  final IntercityBookingPassenger? passenger;
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? passengerComment;
  final DateTime? pickupReachedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool chatAvailable;

  bool get canCancel => status == IntercityRideBookingStatus.confirmed;

  IntercityPickupDraft? get pickup {
    final address = pickupAddress?.trim() ?? '';
    final lat = pickupLat;
    final lng = pickupLng;
    if (address.isEmpty || lat == null || lng == null) return null;
    final value = IntercityPickupDraft(
      address: address,
      latitude: lat,
      longitude: lng,
      passengerComment: passengerComment,
    );
    return value.isComplete ? value : null;
  }

  factory IntercityRideBooking.fromJson(Map<String, dynamic> json) {
    final route = intercityMap(json['route']) ?? const <String, dynamic>{};
    final driver = intercityMap(json['driver']);
    final passenger = intercityMap(json['passenger']);
    return IntercityRideBooking(
      bookingId: intercityString(json['bookingId']),
      rideId: intercityString(json['rideId']),
      seats: intercityInt(json['seats']),
      pricePerSeat: intercityInt(json['pricePerSeat']),
      totalPrice: intercityInt(json['totalPrice']),
      status: _bookingStatus(json['status']),
      route: IntercityBookingRoute.fromJson(route),
      departureAt: intercityDateTime(json['departureAt']),
      rideStatus: intercityString(json['rideStatus']),
      driver: driver == null ? null : IntercityBookingDriver.fromJson(driver),
      passenger: passenger == null
          ? null
          : IntercityBookingPassenger.fromJson(passenger),
      pickupAddress: _nullableText(json['pickupAddress']),
      pickupLat: intercityDouble(json['pickupLat']),
      pickupLng: intercityDouble(json['pickupLng']),
      passengerComment: _nullableText(json['passengerComment']),
      pickupReachedAt: intercityDateTime(json['pickupReachedAt']),
      createdAt: intercityDateTime(json['createdAt']),
      updatedAt: intercityDateTime(json['updatedAt']),
      chatAvailable: json['chatAvailable'] == true,
    );
  }
}

IntercityRideBookingStatus _bookingStatus(Object? value) =>
    switch (value?.toString()) {
      'confirmed' => IntercityRideBookingStatus.confirmed,
      'cancelled' => IntercityRideBookingStatus.cancelled,
      'completed' => IntercityRideBookingStatus.completed,
      _ => IntercityRideBookingStatus.unknown,
    };

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
