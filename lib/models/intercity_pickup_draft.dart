import 'package:latlong2/latlong.dart';

class IntercityPickupDraft {
  const IntercityPickupDraft({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.passengerComment,
  });

  final String address;
  final double latitude;
  final double longitude;
  final String? passengerComment;

  bool get isComplete =>
      address.trim().isNotEmpty &&
      latitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude.isFinite &&
      longitude >= -180 &&
      longitude <= 180;

  LatLng get point => LatLng(latitude, longitude);

  IntercityPickupDraft copyWith({
    String? address,
    double? latitude,
    double? longitude,
    String? passengerComment,
    bool clearPassengerComment = false,
  }) => IntercityPickupDraft(
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    passengerComment: clearPassengerComment
        ? null
        : passengerComment ?? this.passengerComment,
  );

  String get logicalPayloadKey =>
      '${address.trim()}|$latitude|$longitude|${passengerComment?.trim() ?? ''}';
}
