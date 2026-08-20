import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/active_order_service.dart';
import '../services/splash_startup_service.dart';
import '../services/startup_diagnostics.dart';
import '../services/user_profile_recovery_service.dart';
import 'auth/login_screen.dart';
import 'auth/user_profile_recovery_screen.dart';
import 'driver/driver_map_screen.dart';
import 'map/map_screen.dart';
import 'map/order_tracking_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.startupLoader,
    this.appInitialization,
    this.timeoutFallback,
    this.onNavigate,
    this.initializeVideo = false,
    this.maximumDuration = const Duration(seconds: 4),
  });

  final Future<SplashDestination> Function()? startupLoader;
  final Future<void>? appInitialization;
  final SplashDestination Function()? timeoutFallback;
  final ValueChanged<SplashDestination>? onNavigate;

  @Deprecated('Тестовый вспомогательный метод.')
  final bool initializeVideo;

  final Duration maximumDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();

    StartupDiagnostics.mark('static splash initialized');
    unawaited(_startStartup());
  }

  Future<void> _startStartup() async {
    try {
      final initialization = widget.appInitialization;

      if (initialization != null) {
        await initialization;
      }

      if (!mounted || _hasNavigated) return;

      // ??? ?????? ? ??????????? ????????? ????????? ?????? injectable loader.
      if (widget.startupLoader != null) {
        final destination = await widget.startupLoader!();

        if (!mounted || _hasNavigated) return;

        _navigateDestination(destination);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _replace(const LoginScreen(), 'login');
        return;
      }

      // ??????????? ?????????:
      // ?? ???? Firestore profile recovery ? VPS active-order lookup.
      // ????? ????????? ??????????.
      _replace(const _FastStartupGate(), 'fastAppGate');
    } catch (error, stackTrace) {
      StartupDiagnostics.error('splash startup failed', error);
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || _hasNavigated) return;

      setState(() {
        _startupError = error.toString();
      });
    }
  }

  void _navigateDestination(SplashDestination destination) {
    widget.onNavigate?.call(destination);

    final activeOrder = destination.activeOrder;

    final screen = switch (destination.target) {
      SplashTarget.login => const LoginScreen(),
      SplashTarget.profileRecovery => const UserProfileRecoveryScreen(),
      SplashTarget.map => const _FastStartupGate(),
      SplashTarget.passengerOrder => OrderTrackingScreen(
        orderId: activeOrder!.orderId,
        initialOrderData: activeOrder.data,
      ),
      SplashTarget.driverOrder => DriverMapScreen(
        orderId: activeOrder!.orderId,
        orderData: activeOrder.data,
      ),
    };

    _replace(screen, destination.target.name);
  }

  void _replace(Widget screen, String target) {
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;

    StartupDiagnostics.mark('navigation target=$target');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _startupError;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 170,
                  height: 170,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                if (error == null)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.amber,
                    ),
                  )
                else ...[
                  const Text(
                    'Не удалось запустить приложение',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _startupError = null;
                        _hasNavigated = false;
                      });

                      unawaited(_startStartup());
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Повторить'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ???????????? ??? ???????????.
///
/// ????? ???????????? ??????????, ? ???????? ??????????? ???????????.
/// ??????? ???????? ?????? ?? ?????? ???????????? ?? splash.
class _FastStartupGate extends StatefulWidget {
  const _FastStartupGate();

  @override
  State<_FastStartupGate> createState() => _FastStartupGateState();
}

class _FastStartupGateState extends State<_FastStartupGate> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();

    StartupDiagnostics.mark('map shown before background recovery');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runBackgroundRecovery());
    });
  }

  Future<void> _runBackgroundRecovery() async {
    try {
      final recoveryFuture = UserProfileRecoveryService().inspectAndRepair();

      final activeOrderFuture = ActiveOrderService().findCurrentOrder();

      final recovery = await recoveryFuture;

      StartupDiagnostics.mark('background profile recovery resolved');

      if (!mounted || _handled) return;

      if (!recovery.allowsAppAccess) {
        _handled = true;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileRecoveryScreen(initialResult: recovery),
          ),
        );

        return;
      }

      final activeOrder = await activeOrderFuture;

      StartupDiagnostics.mark('background active order resolved');

      if (!mounted || _handled || activeOrder == null) return;

      _handled = true;

      if (activeOrder.isDriver) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverMapScreen(
              orderId: activeOrder.orderId,
              orderData: activeOrder.data,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(
              orderId: activeOrder.orderId,
              initialOrderData: activeOrder.data,
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      // ?????? ??????? ???????? ?? ?????? ??????????? ???? ? ??????????.
      StartupDiagnostics.error('background startup recovery failed', error);

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MapScreen();
  }
}
