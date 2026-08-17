import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';
import 'app_routes.dart';
import 'screens/auth/login_screen.dart';
import 'screens/driver/driver_subscription_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/profile/history_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart';
import 'services/theme_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

const _useFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
const _useCloudFunctions = bool.fromEnvironment('USE_CLOUD_FUNCTIONS');
const _emulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeLoad = appThemeController.load();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform.copyWith(
        databaseURL: 'https://taxi-esil-default-rtdb.firebaseio.com',
      ),
    );
    debugPrint('Firebase успешно инициализирован');
  } catch (e, stack) {
    debugPrint('Ошибка при инициализации Firebase: $e');
    debugPrint(stack.toString());
  }

  if (_useFirebaseEmulators) {
    await _connectFirebaseEmulators();
  } else if (_useCloudFunctions) {
    await PushNotificationService().initialize(
      navigatorKey: navigatorKey,
      messengerKey: scaffoldMessengerKey,
    );
  }

  await themeLoad;

  runApp(const TaxiApp());
}

class TaxiApp extends StatelessWidget {
  const TaxiApp({super.key, this.themeController, this.home});

  final ThemeController? themeController;
  final Widget? home;

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
          AppRoutes.map: (_) => const MapScreen(),
          AppRoutes.driverSubscription: (_) => const DriverSubscriptionScreen(),
          AppRoutes.history: (_) => const HistoryScreen(),
          AppRoutes.profile: (_) => const ProfileScreen(),
          AppRoutes.login: (_) => const LoginScreen(),
        },
        home: home ?? const SplashScreen(),
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
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  FirebaseDatabase.instance.useDatabaseEmulator(_emulatorHost, 9000);
  FirebaseFunctions.instance.useFunctionsEmulator(_emulatorHost, 5001);
  debugPrint('Firebase Emulator Suite: $_emulatorHost');
}
