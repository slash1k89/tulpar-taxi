import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../l10n/generated/app_localizations.dart';
import '../screens/map/order_tracking_screen.dart';
import 'active_order_service.dart';

class PassengerOperationalStateResolver {
  PassengerOperationalStateResolver({
    Future<ActiveOrder?> Function()? loader,
    ActiveOrder? Function()? lastKnownOrder,
  }) : _loader = loader ?? ActiveOrderService().findCurrentOrderOrThrow,
       _lastKnownOrder =
           lastKnownOrder ?? (() => ActiveOrderService.lastKnownActiveOrder);

  final Future<ActiveOrder?> Function() _loader;
  final ActiveOrder? Function() _lastKnownOrder;

  Future<void> openTaxi(BuildContext context, {bool clearStack = false}) async {
    final navigator = Navigator.of(context);
    ActiveOrder? active;
    try {
      active = await _loader();
    } catch (_) {
      active = _lastKnownOrder();
      if (active == null || active.isDriver) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).serverTimeout)),
          );
        }
        return;
      }
    }
    if (!context.mounted) return;

    final resolvedActive = active;
    if (resolvedActive != null && !resolvedActive.isDriver) {
      final route = MaterialPageRoute<void>(
        builder: (_) => OrderTrackingScreen(
          orderId: resolvedActive.orderId,
          initialOrderData: resolvedActive.data,
        ),
      );
      if (clearStack) {
        navigator.pushAndRemoveUntil(route, (_) => false);
      } else {
        navigator.pushReplacement(route);
      }
      return;
    }

    if (clearStack) {
      navigator.pushNamedAndRemoveUntil(AppRoutes.map, (_) => false);
    } else {
      navigator.pushReplacementNamed(AppRoutes.map);
    }
  }
}
