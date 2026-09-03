import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/driver_approaching_notification.dart';

void main() {
  test('approaching event has fixed user-facing copy', () {
    expect(driverApproachingPickupTitle, 'Водитель скоро будет на месте');
    expect(
      driverApproachingPickupBody,
      'Пожалуйста, выходите к месту подачи — водитель уже подъезжает.',
    );
  });

  test('approaching is visible in foreground and opens order tracking', () {
    expect(driverApproachingShowsForeground('driver_approaching'), isTrue);
    expect(driverApproachingOpensOrderTracking('driver_approaching'), isTrue);
    expect(
      driverApproachingShowsForeground(driverApproachingPickupEvent),
      isTrue,
    );
    expect(
      driverApproachingOpensOrderTracking(driverApproachingPickupEvent),
      isTrue,
    );
    expect(driverApproachingShowsForeground('driver_location'), isFalse);
    expect(driverApproachingOpensOrderTracking('chat_message'), isFalse);
  });
}
