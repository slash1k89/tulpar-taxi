import 'intercity_ride_json.dart';
import 'intercity_pickup_draft.dart';

enum IntercityRideRequestStatus { active, cancelled, expired, unknown }

class IntercityRideRequest {
  const IntercityRideRequest({
    required this.requestId,
    required this.originCity,
    required this.destinationCity,
    required this.travelDate,
    required this.seats,
    required this.status,
    required this.matchedRideIds,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.passengerComment,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
  });

  final String requestId;
  final String originCity;
  final String destinationCity;
  final DateTime? travelDate;
  final int seats;
  final IntercityRideRequestStatus status;
  final List<String> matchedRideIds;
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? passengerComment;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canCancel => status == IntercityRideRequestStatus.active;

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

  factory IntercityRideRequest.fromJson(Map<String, dynamic> json) {
    final rawMatches = json['matchedRideIds'];
    return IntercityRideRequest(
      requestId: intercityString(json['requestId']),
      originCity: intercityString(json['originCity']),
      destinationCity: intercityString(json['destinationCity']),
      travelDate: intercityDateTime(json['travelDate']),
      seats: intercityInt(json['seats']),
      status: _requestStatus(json['status']),
      matchedRideIds: rawMatches is List
          ? rawMatches
                .map((value) => value?.toString() ?? '')
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const [],
      pickupAddress: _nullableText(json['pickupAddress']),
      pickupLat: intercityDouble(json['pickupLat']),
      pickupLng: intercityDouble(json['pickupLng']),
      passengerComment: _nullableText(json['passengerComment']),
      cancelledAt: intercityDateTime(json['cancelledAt']),
      createdAt: intercityDateTime(json['createdAt']),
      updatedAt: intercityDateTime(json['updatedAt']),
    );
  }
}

IntercityRideRequestStatus _requestStatus(Object? value) =>
    switch (value?.toString()) {
      'active' => IntercityRideRequestStatus.active,
      'cancelled' => IntercityRideRequestStatus.cancelled,
      'expired' => IntercityRideRequestStatus.expired,
      _ => IntercityRideRequestStatus.unknown,
    };

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
