const intercityRideMaximumSeats = 7;
const intercityRideMaximumPricePerSeat = 1000000;
const intercityRideMaximumCommentLength = 1000;

class IntercityDriverRideDraft {
  const IntercityDriverRideDraft({
    required this.originCity,
    required this.destinationCity,
    required this.departureAt,
    required this.totalSeats,
    required this.pricePerSeat,
    required this.allowsLuggage,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.comment,
  });

  final String originCity;
  final double? originLat;
  final double? originLng;
  final String destinationCity;
  final double? destinationLat;
  final double? destinationLng;
  final DateTime departureAt;
  final int totalSeats;
  final int pricePerSeat;
  final bool allowsLuggage;
  final String? comment;

  Map<String, dynamic> toCreateJson() => {
    'originCity': originCity.trim(),
    if (originLat != null && originLng != null) ...{
      'originLat': originLat,
      'originLng': originLng,
    },
    'destinationCity': destinationCity.trim(),
    if (destinationLat != null && destinationLng != null) ...{
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
    },
    'departureAt': departureAt.toUtc().toIso8601String(),
    'totalSeats': totalSeats,
    'pricePerSeat': pricePerSeat,
    'allowsLuggage': allowsLuggage,
    'comment': _cleanComment,
  };

  Map<String, dynamic> toPatchJson({required bool hasConfirmedBooking}) => {
    if (!hasConfirmedBooking) ...{
      'originCity': originCity.trim(),
      if (originLat != null && originLng != null) ...{
        'originLat': originLat,
        'originLng': originLng,
      },
      'destinationCity': destinationCity.trim(),
      if (destinationLat != null && destinationLng != null) ...{
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
      },
      'departureAt': departureAt.toUtc().toIso8601String(),
      'totalSeats': totalSeats,
    },
    'pricePerSeat': pricePerSeat,
    'allowsLuggage': allowsLuggage,
    'comment': _cleanComment,
  };

  String? get _cleanComment {
    final value = comment?.trim() ?? '';
    return value.isEmpty ? null : value;
  }
}
