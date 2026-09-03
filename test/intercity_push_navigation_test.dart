import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/push_notification_service.dart';

void main() {
  test('passenger intercity push targets are safe and specific', () {
    expect(
      intercityPassengerPushTarget({
        'type': 'intercity_ride_match_available',
        'rideId': 'ride-1',
      }),
      IntercityPassengerPushTarget.rideDetails,
    );
    expect(
      intercityPassengerPushTarget({'type': 'intercity_ride_match_available'}),
      IntercityPassengerPushTarget.requests,
    );
    expect(
      intercityPassengerPushTarget({'type': 'intercity_ride_cancelled'}),
      IntercityPassengerPushTarget.bookings,
    );
    expect(
      intercityPassengerPushTarget({'type': 'intercity_ride_departed'}),
      IntercityPassengerPushTarget.bookings,
    );
  });

  test('unknown intercity push is intercepted but opens no chat target', () {
    expect(isIntercityRidePushEvent('intercity_unknown_event'), isTrue);
    expect(
      intercityPassengerPushTarget({'type': 'intercity_unknown_event'}),
      IntercityPassengerPushTarget.none,
    );
    expect(
      intercityPassengerPushTarget({'type': 'intercity_ride_booked'}),
      IntercityPassengerPushTarget.none,
    );
    expect(
      intercityPassengerPushTarget({'type': 'intercity_booking_cancelled'}),
      IntercityPassengerPushTarget.none,
    );
  });

  test('city, delivery and legacy order events keep old routing branch', () {
    expect(isIntercityRidePushEvent('accepted'), isFalse);
    expect(isIntercityRidePushEvent('driver_arrived'), isFalse);
    expect(isIntercityRidePushEvent('chat_message'), isFalse);
    expect(isIntercityRidePushEvent(null), isFalse);
  });
}
