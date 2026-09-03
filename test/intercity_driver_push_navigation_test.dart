import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/push_notification_service.dart';

void main() {
  test('driver booking events open the owned ride area', () {
    expect(
      intercityDriverPushTarget({
        'type': 'intercity_ride_booked',
        'rideId': 'ride-1',
      }),
      IntercityDriverPushTarget.rideDetails,
    );
    expect(
      intercityDriverPushTarget({
        'type': 'intercity_booking_cancelled',
        'rideId': 'ride-1',
      }),
      IntercityDriverPushTarget.rideDetails,
    );
    expect(
      intercityDriverPushTarget({'type': 'intercity_ride_booked'}),
      IntercityDriverPushTarget.rides,
    );
  });

  test('passenger and unknown events do not enter driver ride details', () {
    expect(
      intercityDriverPushTarget({'type': 'intercity_ride_cancelled'}),
      IntercityDriverPushTarget.none,
    );
    expect(
      intercityDriverPushTarget({'type': 'intercity_ride_match_available'}),
      IntercityDriverPushTarget.none,
    );
    expect(isIntercityRidePushEvent('intercity_unknown_event'), isTrue);
    expect(
      intercityDriverPushTarget({'type': 'intercity_unknown_event'}),
      IntercityDriverPushTarget.none,
    );
  });
}
