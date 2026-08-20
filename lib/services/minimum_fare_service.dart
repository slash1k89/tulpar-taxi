typedef UtcNow = DateTime Function();

/// Single source of truth for Tulpar's passenger minimum fare.
///
/// Kazakhstan uses UTC+5 nationwide. The production clock is converted from
/// UTC explicitly, so the fare does not depend on the phone's configured time
/// zone. Supplied instants are treated as real instants and converted to UTC+5.
class MinimumFareService {
  MinimumFareService({UtcNow? utcNow}) : _utcNow = utcNow ?? _systemUtcNow;

  static const int dayMinimumFare = 600;
  static const int nightMinimumFare = 700;
  static const Duration kazakhstanUtcOffset = Duration(hours: 5);

  final UtcNow _utcNow;

  static DateTime _systemUtcNow() => DateTime.now().toUtc();

  int get currentMinimumFare => minimumFareForInstant(_utcNow());

  int minimumFareForInstant(DateTime instant) {
    final kazakhstanTime = instant.toUtc().add(kazakhstanUtcOffset);
    return minimumFareForKazakhstanTime(kazakhstanTime);
  }

  int minimumFareForKazakhstanTime(DateTime localTime) {
    final hour = localTime.hour;
    return hour >= 6 && hour < 22 ? dayMinimumFare : nightMinimumFare;
  }

  int priceWithMinimum(int proposedPrice, {DateTime? at}) {
    final minimum = at == null ? currentMinimumFare : minimumFareForInstant(at);
    return proposedPrice < minimum ? minimum : proposedPrice;
  }

  String messageForMinimum(int minimumFare) =>
      'Минимальная стоимость поездки сейчас — $minimumFare ₸.';
}
