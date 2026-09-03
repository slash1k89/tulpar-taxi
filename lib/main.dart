import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_routes.dart';
import 'screens/auth/login_screen.dart';
import 'screens/driver/driver_onboarding_screen.dart';
import 'screens/driver/driver_intercity_screen.dart';
import 'screens/driver/driver_intercity_mode_screen.dart';
import 'screens/driver/intercity_create_ride_screen.dart';
import 'screens/driver/intercity_driver_rides_screen.dart';
import 'screens/driver/driver_screen.dart';
import 'screens/intercity/intercity_bookings_screen.dart';
import 'screens/intercity/intercity_mode_screen.dart';
import 'screens/intercity/intercity_request_screen.dart';
import 'screens/intercity/intercity_ride_search_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/profile/history_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart';
import 'services/startup_diagnostics.dart';
import 'services/theme_service.dart';
import 'services/tulpar_auth_session.dart';
import 'models/order_service_type.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

const _useFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
const _emulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  StartupDiagnostics.mark('process start');

  final requiredInitialization = _initializeRequiredServices();

  runApp(TaxiApp(startupInitialization: requiredInitialization));
  StartupDiagnostics.mark('runApp');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    StartupDiagnostics.mark('first Flutter frame');
    unawaited(_loadTheme());
    if (!_useFirebaseEmulators) {
      unawaited(_initializeDeferredServices(requiredInitialization));
    }
  });
}

Future<void>? _firebaseInitialization;

Future<void> _initializeFirebase() => _firebaseInitialization ??= () async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform.copyWith(
          databaseURL: 'https://taxi-esil-default-rtdb.firebaseio.com',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
      Firebase.app();
      StartupDiagnostics.mark('Firebase default app reused');
    }
  }
  StartupDiagnostics.mark('Firebase initialized');
}();

Future<void> _initializeRequiredServices() async {
  try {
    final hasTulparSession = await TulparAuthController.instance.restore();
    StartupDiagnostics.mark('Tulpar auth restored');

    if (!hasTulparSession || _useFirebaseEmulators) {
      await _initializeFirebase();
    } else {
      StartupDiagnostics.mark('Firebase initialization deferred');
    }

    if (_useFirebaseEmulators) await _connectFirebaseEmulators();
  } catch (error, stackTrace) {
    StartupDiagnostics.error('Firebase initialization failed', error);
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
}

Future<void> _loadTheme() async {
  try {
    await appThemeController.load();
    StartupDiagnostics.mark('theme preference loaded');
  } catch (error) {
    StartupDiagnostics.error('theme preference load failed', error);
  }
}

Future<void> _initializeDeferredServices(
  Future<void> requiredInitialization,
) async {
  // Required/auth failures still belong to the startup screen.
  try {
    await requiredInitialization;
  } catch (_) {
    return;
  }
  PushNotificationService? push;
  try {
    await _initializeFirebase();
    push = PushNotificationService();
    await push.initialize(
      navigatorKey: navigatorKey,
      messengerKey: scaffoldMessengerKey,
    );
    StartupDiagnostics.mark('push notifications initialized');
  } catch (error) {
    StartupDiagnostics.error('deferred services failed', error);
    await push?.dispose();
    _firebaseInitialization = null;
    // Retry optional FCM setup without delaying auth or the first screen.
    Timer(const Duration(seconds: 30), () {
      unawaited(_initializeDeferredServices(requiredInitialization));
    });
  }
}

class TaxiApp extends StatelessWidget {
  const TaxiApp({
    super.key,
    this.themeController,
    this.home,
    this.startupInitialization,
  });

  final ThemeController? themeController;
  final Widget? home;
  final Future<void>? startupInitialization;

  @override
  Widget build(BuildContext context) {
    final controller = themeController ?? appThemeController;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        title: 'TULPAR taxi',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        themeMode: controller.themeMode,
        theme: ThemeData.light().copyWith(
          scaffoldBackgroundColor: const Color(0xFFF7F7F7),
          primaryColor: Colors.amber,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
          ),
          drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
          inputDecorationTheme: _inputDecorationTheme(
            fillColor: Colors.white,
            borderColor: Colors.black12,
          ),
          elevatedButtonTheme: _elevatedButtonTheme(),
        ),
        darkTheme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          primaryColor: Colors.amber,
          canvasColor: const Color(0xFF1E1E1E),
          cardColor: const Color(0xFF1E1E1E),
          colorScheme: const ColorScheme.dark(
            primary: Colors.amber,
            secondary: Colors.amberAccent,
            surface: Color(0xFF1E1E1E),
            onPrimary: Colors.black,
            onSurface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            foregroundColor: Colors.amber,
            elevation: 0,
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: Color(0xFF1E1E1E),
          ),
          inputDecorationTheme: _inputDecorationTheme(
            fillColor: const Color(0xFF2C2C2C),
            borderColor: Colors.white10,
          ),
          elevatedButtonTheme: _elevatedButtonTheme(),
        ),
        routes: {
          AppRoutes.map: (_) =>
              const MapScreen(serviceType: OrderServiceType.city),
          AppRoutes.delivery: (_) =>
              const MapScreen(serviceType: OrderServiceType.delivery),
          AppRoutes.intercity: (_) => const IntercityModeScreen(),
          AppRoutes.intercityOrder: (_) =>
              const MapScreen(serviceType: OrderServiceType.intercity),
          AppRoutes.intercityRideSearch: (_) =>
              const IntercityRideSearchScreen(),
          AppRoutes.intercityBookings: (_) => const IntercityBookingsScreen(),
          AppRoutes.intercityRequests: (_) => const IntercityRequestScreen(),
          AppRoutes.driverTaxi: (_) =>
              const DriverScreen(serviceType: OrderServiceType.city),
          AppRoutes.driverDelivery: (_) =>
              const DriverScreen(serviceType: OrderServiceType.delivery),
          AppRoutes.driverIntercity: (_) => const DriverIntercityModeScreen(),
          AppRoutes.driverIntercityOrders: (_) => const DriverIntercityScreen(),
          AppRoutes.driverIntercityRides: (_) =>
              const IntercityDriverRidesScreen(),
          AppRoutes.driverIntercityCreate: (_) =>
              const IntercityCreateRideScreen(),
          AppRoutes.driverOnboarding: (_) => const DriverOnboardingScreen(),
          AppRoutes.history: (_) => const HistoryScreen(),
          AppRoutes.profile: (_) => const ProfileScreen(),
          AppRoutes.login: (_) => const LoginScreen(),
        },
        home: home ?? SplashScreen(appInitialization: startupInitialization),
      ),
    );
  }
}

InputDecorationTheme _inputDecorationTheme({
  required Color fillColor,
  required Color borderColor,
}) {
  return InputDecorationTheme(
    filled: true,
    fillColor: fillColor,
    labelStyle: const TextStyle(color: Colors.grey),
    hintStyle: const TextStyle(color: Colors.grey),
    prefixIconColor: Colors.amber,
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Colors.amber, width: 2),
    ),
  );
}

ElevatedButtonThemeData _elevatedButtonTheme() {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.amber,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );
}

Future<void> _connectFirebaseEmulators() async {
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  debugPrint('Firebase Emulator Suite: $_emulatorHost');
}
