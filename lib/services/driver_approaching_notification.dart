const driverApproachingPickupEvent = 'driver_approaching_pickup';
const driverApproachingPickupTitle = 'Водитель скоро будет на месте';
const driverApproachingPickupBody =
    'Пожалуйста, выходите к месту подачи — водитель уже подъезжает.';

bool isDriverApproachingPickup(Object? eventType) =>
    eventType?.toString() == driverApproachingPickupEvent ||
    // Receive-only compatibility alias; the backend's canonical event is unchanged.
    eventType?.toString() == 'driver_approaching';

bool driverApproachingShowsForeground(Object? eventType) =>
    isDriverApproachingPickup(eventType);

bool driverApproachingOpensOrderTracking(Object? eventType) =>
    isDriverApproachingPickup(eventType);
