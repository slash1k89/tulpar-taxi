import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/intercity_contact_service.dart';
import 'package:taxi_esil/services/intercity_ride_service.dart';
import 'package:taxi_esil/models/intercity_ride_booking.dart';

void main() {
  test(
    'WhatsApp deep link contains only normalized confirmed contact phone',
    () {
      expect(
        intercityWhatsAppUri('+7 (700) 123-45-67').toString(),
        'https://wa.me/77001234567',
      );
      expect(intercityWhatsAppUri(null), isNull);
      expect(intercityWhatsAppUri('123'), isNull);
    },
  );

  test('navigation keeps confirmed passenger pickup order', () {
    IntercityRideBooking booking(
      int index,
      IntercityRideBookingStatus status,
    ) => IntercityRideBooking(
      bookingId: 'b$index',
      rideId: 'ride',
      seats: 1,
      pricePerSeat: 1,
      totalPrice: 1,
      status: status,
      route: const IntercityBookingRoute(
        originCity: 'Есиль',
        destinationCity: 'Астана',
      ),
      rideStatus: 'scheduled',
      pickupAddress: 'P$index',
      pickupLat: 51.0 + index,
      pickupLng: 66.0 + index,
    );
    final points = intercityNavigationPickups([
      booking(1, IntercityRideBookingStatus.confirmed),
      booking(2, IntercityRideBookingStatus.cancelled),
      booking(3, IntercityRideBookingStatus.confirmed),
    ]);
    expect(points.map((point) => point.address), ['P1', 'P3']);
  });
}
