import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/models/intercity_ride.dart';
import 'package:taxi_esil/models/intercity_ride_booking.dart';
import 'package:taxi_esil/models/next_order.dart';
import 'package:taxi_esil/screens/auth/register_screen.dart';
import 'package:taxi_esil/screens/auth/user_profile_recovery_screen.dart';
import 'package:taxi_esil/screens/driver/intercity_create_ride_screen.dart';
import 'package:taxi_esil/screens/driver/intercity_driver_ride_details_screen.dart';
import 'package:taxi_esil/screens/driver/driver_order_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_ride_details_screen.dart';
import 'package:taxi_esil/screens/driver_navigation_screen.dart';
import 'package:taxi_esil/services/geocoding_service.dart';
import 'package:taxi_esil/services/intercity_ride_service.dart';
import 'package:taxi_esil/services/user_profile_recovery_service.dart';
import 'package:taxi_esil/widgets/next_order_candidate_card.dart';
import 'package:taxi_esil/widgets/tulpar_time_picker.dart';

Widget _app(String language, Widget home) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

final _ride = IntercityRide(
  rideId: 'ride-1',
  originCity: 'Есиль',
  destinationCity: 'Астана',
  departureAt: DateTime.utc(2030, 9, 3, 7),
  totalSeats: 4,
  availableSeats: 3,
  pricePerSeat: 4000,
  allowsLuggage: true,
  status: IntercityRideStatus.scheduled,
);

const _origin = KazakhstanSettlement(
  id: 'esil',
  name: 'Есиль',
  region: '',
  lat: 51.95,
  lng: 66.4,
);
const _destination = KazakhstanSettlement(
  id: 'astana',
  name: 'Астана',
  region: '',
  lat: 51.16,
  lng: 71.47,
);

class _DetailsRepository extends IntercityRideService {
  @override
  Future<IntercityRide> getDriverRide(String rideId) async => _ride;

  @override
  Future<List<IntercityRideBooking>> getDriverRideBookings(
    String rideId,
  ) async => [];
}

void main() {
  for (final (locale, recover, save, book, create, passengers, month) in [
    (
      'kk',
      'Профильді қалпына келтіру',
      'Сақтап, жалғастыру',
      'Брондау',
      'Сапар құру',
      'Жолаушылар',
      'қыркүйек',
    ),
    (
      'en',
      'Restore profile',
      'Save and continue',
      'Book',
      'Create ride',
      'Passengers',
      'September',
    ),
  ]) {
    testWidgets('$locale recovery, registration and time picker labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          locale,
          const UserProfileRecoveryScreen(
            initialResult: UserProfileRecoveryResult(
              state: UserProfileRecoveryState.needsName,
              missingFields: ['name'],
              adminMigrationFields: [],
              safeClientUpdate: {},
              legacyFieldsPresent: false,
            ),
          ),
        ),
      );
      expect(find.text(recover), findsOneWidget);
      expect(find.text(save), findsOneWidget);

      await tester.pumpWidget(_app(locale, const RegisterScreen()));
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text(locale == 'en' ? 'Register' : 'Тіркелу'), findsWidgets);

      await tester.pumpWidget(
        _app(
          locale,
          const Scaffold(
            body: TulparTimePicker(initialTime: TimeOfDay(hour: 8, minute: 30)),
          ),
        ),
      );
      expect(
        find.text(locale == 'en' ? 'Choose time' : 'Уақытты таңдаңыз'),
        findsOneWidget,
      );
    });

    testWidgets('$locale passenger booking and driver ride date use locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(locale, IntercityRideDetailsScreen(ride: _ride)),
      );
      expect(
        find.text(locale == 'en' ? '3 seats available' : 'Бос орын: 3'),
        findsOneWidget,
      );
      expect(find.textContaining(month), findsWidgets);
      expect(find.textContaining('сентября'), findsNothing);
      expect(
        find.textContaining(locale == 'en' ? book : 'брондау'),
        findsWidgets,
      );

      await tester.pumpWidget(
        _app(
          locale,
          IntercityDriverRideDetailsScreen(
            rideId: _ride.rideId,
            initialRide: _ride,
            repository: _DetailsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(passengers),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(passengers), findsOneWidget);
    });

    testWidgets('$locale driver create and next-order card labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          locale,
          IntercityCreateRideScreen(
            initialOrigin: _origin,
            initialDestination: _destination,
            initialDepartureAt: DateTime.utc(2030, 9, 3, 7),
          ),
        ),
      );
      expect(find.text(create), findsOneWidget);

      await tester.pumpWidget(
        _app(
          locale,
          Scaffold(
            body: NextOrderCandidateCard(
              candidate: const NextOrderCandidate(
                orderId: 'next',
                pickupAddress: 'A',
                destinationAddress: 'B',
                passengerPrice: 1500,
                distanceToCurrentDestinationMeters: 200,
              ),
              isAccepting: false,
              onAccept: () {},
              onOffer: () {},
            ),
          ),
        ),
      );
      expect(
        find.text(
          locale == 'en' ? 'Next order nearby' : 'Келесі тапсырыс жақын',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          locale == 'en' ? 'Pickup in 200 m' : 'Алу орнына дейін 200 м',
        ),
        findsOneWidget,
      );
    });

    testWidgets('$locale legacy driver order and navigation labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          locale,
          DriverOrderScreen(
            orderId: 'order',
            enableTracking: false,
            orderDetailsStream: Stream.value({
              'status': 'accepted',
              'passengerName': 'A',
              'passengerPhone': '+77000000000',
              'fromAddress': 'B',
              'toAddress': 'C',
              'price': 1200,
            }),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(locale == 'en' ? 'Heading to passenger' : 'Клиентке барамыз'),
        findsOneWidget,
      );
      expect(
        find.text(locale == 'en' ? 'At pickup' : 'Орнында'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _app(
          locale,
          const DriverNavigationScreen(
            destinationLat: 51.16,
            destinationLng: 71.47,
          ),
        ),
      );
      expect(
        find.text(locale == 'en' ? 'Order navigation' : 'Тапсырыс бағыты'),
        findsOneWidget,
      );
      expect(
        find.text(
          locale == 'en' ? 'Map appears here' : 'Карта осы жерде көрсетіледі',
        ),
        findsOneWidget,
      );
    });
  }
}
