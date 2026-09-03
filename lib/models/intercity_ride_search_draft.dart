import '../services/geocoding_service.dart';

class IntercityRideSearchDraft {
  const IntercityRideSearchDraft({
    required this.origin,
    required this.destination,
    required this.travelDate,
    required this.seats,
  });

  final KazakhstanSettlement origin;
  final KazakhstanSettlement destination;
  final DateTime travelDate;
  final int seats;
}
