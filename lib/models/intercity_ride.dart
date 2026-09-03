import 'intercity_ride_json.dart';

enum IntercityRideStatus { scheduled, departed, completed, cancelled, unknown }

class IntercityRideDriver {
  const IntercityRideDriver({this.name, this.carModel, this.carColor});

  final String? name;
  final String? carModel;
  final String? carColor;

  factory IntercityRideDriver.fromJson(Map<String, dynamic> json) =>
      IntercityRideDriver(
        name: _nullableText(json['name']),
        carModel: _nullableText(json['carModel']),
        carColor: _nullableText(json['carColor']),
      );
}

class IntercityRide {
  const IntercityRide({
    required this.rideId,
    required this.originCity,
    required this.destinationCity,
    required this.totalSeats,
    required this.availableSeats,
    required this.pricePerSeat,
    required this.allowsLuggage,
    required this.status,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.departureAt,
    this.comment,
    this.driver,
    this.createdAt,
    this.updatedAt,
  });

  final String rideId;
  final String originCity;
  final double? originLat;
  final double? originLng;
  final String destinationCity;
  final double? destinationLat;
  final double? destinationLng;
  final DateTime? departureAt;
  final int totalSeats;
  final int availableSeats;
  final int pricePerSeat;
  final bool allowsLuggage;
  final String? comment;
  final IntercityRideStatus status;
  final IntercityRideDriver? driver;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canBook =>
      status == IntercityRideStatus.scheduled && availableSeats > 0;

  factory IntercityRide.fromJson(Map<String, dynamic> json) {
    final driver = intercityMap(json['driver']);
    return IntercityRide(
      rideId: intercityString(json['rideId']),
      originCity: intercityString(json['originCity']),
      originLat: intercityDouble(json['originLat']),
      originLng: intercityDouble(json['originLng']),
      destinationCity: intercityString(json['destinationCity']),
      destinationLat: intercityDouble(json['destinationLat']),
      destinationLng: intercityDouble(json['destinationLng']),
      departureAt: intercityDateTime(json['departureAt']),
      totalSeats: intercityInt(json['totalSeats']),
      availableSeats: intercityInt(json['availableSeats']),
      pricePerSeat: intercityInt(json['pricePerSeat']),
      allowsLuggage: json['allowsLuggage'] == true,
      comment: _nullableText(json['comment']),
      status: _rideStatus(json['status']),
      driver: driver == null ? null : IntercityRideDriver.fromJson(driver),
      createdAt: intercityDateTime(json['createdAt']),
      updatedAt: intercityDateTime(json['updatedAt']),
    );
  }

  IntercityRide copyWith({int? availableSeats}) => IntercityRide(
    rideId: rideId,
    originCity: originCity,
    originLat: originLat,
    originLng: originLng,
    destinationCity: destinationCity,
    destinationLat: destinationLat,
    destinationLng: destinationLng,
    departureAt: departureAt,
    totalSeats: totalSeats,
    availableSeats: availableSeats ?? this.availableSeats,
    pricePerSeat: pricePerSeat,
    allowsLuggage: allowsLuggage,
    comment: comment,
    status: status,
    driver: driver,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

IntercityRideStatus _rideStatus(Object? value) => switch (value?.toString()) {
  'scheduled' => IntercityRideStatus.scheduled,
  'departed' => IntercityRideStatus.departed,
  'completed' => IntercityRideStatus.completed,
  'cancelled' => IntercityRideStatus.cancelled,
  _ => IntercityRideStatus.unknown,
};

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
