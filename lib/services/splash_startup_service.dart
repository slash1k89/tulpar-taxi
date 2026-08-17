import 'package:firebase_auth/firebase_auth.dart';

import 'active_order_service.dart';

enum SplashTarget { login, map, passengerOrder, driverOrder }

class SplashDestination {
  const SplashDestination._(this.target, this.activeOrder);

  const SplashDestination.login() : this._(SplashTarget.login, null);

  const SplashDestination.map() : this._(SplashTarget.map, null);

  const SplashDestination.passengerOrder(ActiveOrder order)
    : this._(SplashTarget.passengerOrder, order);

  const SplashDestination.driverOrder(ActiveOrder order)
    : this._(SplashTarget.driverOrder, order);

  final SplashTarget target;
  final ActiveOrder? activeOrder;
}

class SplashStartupService {
  SplashStartupService({
    Future<bool> Function()? authLoader,
    Future<ActiveOrder?> Function()? activeOrderLoader,
  }) : _authLoader = authLoader ?? _loadAuth,
       _activeOrderLoader =
           activeOrderLoader ?? ActiveOrderService().findCurrentOrder;

  final Future<bool> Function() _authLoader;
  final Future<ActiveOrder?> Function() _activeOrderLoader;

  Future<SplashDestination> loadDestination() async {
    final results = await Future.wait<Object?>([
      _authLoader(),
      _activeOrderLoader(),
    ]);
    final isSignedIn = results[0] as bool;
    final activeOrder = results[1] as ActiveOrder?;

    if (!isSignedIn) return const SplashDestination.login();
    if (activeOrder == null) return const SplashDestination.map();
    return activeOrder.isDriver
        ? SplashDestination.driverOrder(activeOrder)
        : SplashDestination.passengerOrder(activeOrder);
  }

  SplashDestination fallbackDestination() {
    return FirebaseAuth.instance.currentUser == null
        ? const SplashDestination.login()
        : const SplashDestination.map();
  }

  static Future<bool> _loadAuth() async {
    return FirebaseAuth.instance.currentUser != null;
  }
}
