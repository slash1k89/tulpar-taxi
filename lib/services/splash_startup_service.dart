import 'package:firebase_auth/firebase_auth.dart';

import 'active_order_service.dart';
import 'startup_diagnostics.dart';
import 'user_profile_recovery_service.dart';
import 'tulpar_auth_session.dart';

enum SplashTarget { login, profileRecovery, map, passengerOrder, driverOrder }

class SplashDestination {
  const SplashDestination._(this.target, this.activeOrder);

  const SplashDestination.login() : this._(SplashTarget.login, null);

  const SplashDestination.profileRecovery()
    : this._(SplashTarget.profileRecovery, null);

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
    Future<UserProfileRecoveryResult> Function()? profileRecoveryLoader,
    Future<ActiveOrder?> Function()? activeOrderLoader,
  }) : _authLoader = authLoader ?? _loadAuth,
       _profileRecoveryLoader =
           profileRecoveryLoader ??
           UserProfileRecoveryService().inspectAndRepair,
       _activeOrderLoader =
           activeOrderLoader ?? ActiveOrderService().findCurrentOrder;

  final Future<bool> Function() _authLoader;
  final Future<UserProfileRecoveryResult> Function() _profileRecoveryLoader;
  final Future<ActiveOrder?> Function() _activeOrderLoader;

  Future<SplashDestination> loadDestination() async {
    final isSignedIn = await _authLoader();
    StartupDiagnostics.mark('auth resolved');
    if (!isSignedIn) return const SplashDestination.login();

    if (TulparAuthController.instance.hasSession) {
      final activeOrder = await _activeOrderLoader();
      if (activeOrder == null) return const SplashDestination.map();
      return activeOrder.isDriver
          ? SplashDestination.driverOrder(activeOrder)
          : SplashDestination.passengerOrder(activeOrder);
    }

    // Keep the profile gate first: an incomplete legacy profile must not
    // continue into order routing. The branded splash remains visible while
    // this read is in progress, so the user never sees a blank loading screen.
    final recovery = await _profileRecoveryLoader();
    StartupDiagnostics.mark('profile recovery resolved');
    if (!recovery.allowsAppAccess) {
      return const SplashDestination.profileRecovery();
    }

    final activeOrder = await _activeOrderLoader();
    StartupDiagnostics.mark('active order lookup resolved');
    if (activeOrder == null) return const SplashDestination.map();
    return activeOrder.isDriver
        ? SplashDestination.driverOrder(activeOrder)
        : SplashDestination.passengerOrder(activeOrder);
  }

  SplashDestination fallbackDestination() {
    return !TulparAuthController.instance.hasSession &&
            FirebaseAuth.instance.currentUser == null
        ? const SplashDestination.login()
        : const SplashDestination.profileRecovery();
  }

  static Future<bool> _loadAuth() async {
    if (await TulparAuthController.instance.restore()) return true;
    return FirebaseAuth.instance.currentUser != null;
  }
}
