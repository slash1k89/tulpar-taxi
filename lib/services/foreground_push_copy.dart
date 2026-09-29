import '../l10n/generated/app_localizations.dart';

typedef ForegroundPushCopy = ({String? title, String body});

ForegroundPushCopy localizedForegroundPushCopy({
  required AppLocalizations l10n,
  required Object? eventType,
  Object? serviceType,
  Object? cancelledBy,
  String? fallbackTitle,
  String? fallbackBody,
}) {
  final delivery = serviceType?.toString() == 'delivery';
  return switch (eventType?.toString()) {
    'driver_approaching_pickup' => (
      title: l10n.pushDriverApproachingTitle,
      body: l10n.pushDriverApproachingBody,
    ),
    'accepted' || 'order_accepted' => (
      title: null,
      body: delivery ? l10n.pushDeliveryAccepted : l10n.pushOrderAccepted,
    ),
    'arrived' || 'driver_arrived' => (
      title: null,
      body: delivery ? l10n.pushDeliveryArrived : l10n.pushDriverArrived,
    ),
    'in_progress' => (
      title: null,
      body: delivery ? l10n.pushDeliveryStarted : l10n.pushTripStarted,
    ),
    'completed' => (
      title: null,
      body: delivery ? l10n.pushDeliveryCompleted : l10n.pushTripCompleted,
    ),
    'cancelled' => (
      title: null,
      body: serviceType?.toString() == 'city'
          ? switch (cancelledBy?.toString()) {
              'passenger' => l10n.pushCityCancelledByPassenger,
              'driver' => l10n.pushCityCancelledByDriver,
              _ => l10n.pushOrderCancelled,
            }
          : l10n.pushOrderCancelled,
    ),
    'expired' => (title: null, body: l10n.pushOrderCancelled),
    'order_created' ||
    'new_driver_order' => (title: null, body: l10n.pushNewDriverOrder),
    'driver_heading_to_pickup' => (title: null, body: l10n.pushDriverHeading),
    'chat_message' => (title: null, body: l10n.pushNewMessage),
    'intercity_ride_match_available' => (
      title: null,
      body: l10n.pushIntercityMatch,
    ),
    'intercity_ride_cancelled' => (
      title: null,
      body: l10n.pushIntercityCancelled,
    ),
    'intercity_ride_departed' => (
      title: null,
      body: l10n.pushIntercityDeparted,
    ),
    'intercity_ride_booked' || 'intercity_booking_created' => (
      title: null,
      body: l10n.pushIntercityBooked,
    ),
    'intercity_booking_cancelled' => (
      title: null,
      body: l10n.pushIntercityBookingCancelled,
    ),
    'intercity_trip_started' => (title: null, body: l10n.pushIntercityDeparted),
    'intercity_trip_completed' => (
      title: null,
      body: l10n.pushIntercityTripCompleted,
    ),
    'intercity_chat_message' => (
      title: fallbackTitle,
      body: fallbackBody ?? l10n.pushIntercityChatMessage,
    ),
    _ => (title: fallbackTitle, body: fallbackBody ?? l10n.pushNewMessage),
  };
}
