import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/order_service_type.dart';
import '../../widgets/app_drawer.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/active_intercity_trip_service.dart';
import 'active_intercity_trip_screen.dart';

class DriverIntercityModeScreen extends StatefulWidget {
  const DriverIntercityModeScreen({
    super.key,
    this.ordersBuilder,
    this.ridesBuilder,
    this.createBuilder,
    this.activeTripResolver,
  });

  final WidgetBuilder? ordersBuilder;
  final WidgetBuilder? ridesBuilder;
  final WidgetBuilder? createBuilder;
  final ActiveIntercityTripResolver? activeTripResolver;

  @override
  State<DriverIntercityModeScreen> createState() =>
      _DriverIntercityModeScreenState();
}

class _DriverIntercityModeScreenState extends State<DriverIntercityModeScreen> {
  late final ActiveIntercityTripResolver _activeTripResolver;
  bool _checkingActive = true;

  @override
  void initState() {
    super.initState();
    _activeTripResolver =
        widget.activeTripResolver ?? ActiveIntercityTripResolver();
    final usesInjectedDestinations =
        widget.ordersBuilder != null ||
        widget.ridesBuilder != null ||
        widget.createBuilder != null;
    if (usesInjectedDestinations && widget.activeTripResolver == null) {
      _checkingActive = false;
    } else {
      _restoreActiveTrip();
    }
  }

  Future<void> _restoreActiveTrip() async {
    final result = await _activeTripResolver.resolve();
    if (!mounted) return;
    final trip = result.trip;
    if (trip != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveIntercityTripScreen(trip: trip),
        ),
      );
      return;
    }
    setState(() => _checkingActive = false);
    if (result.kind == ActiveIntercityTripResolutionKind.unknown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).intercityActiveTripUnknown,
          ),
        ),
      );
    }
  }

  void _open(BuildContext context, String route, WidgetBuilder? builder) {
    if (builder != null) {
      Navigator.push(context, MaterialPageRoute(builder: builder));
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).serviceIntercity)),
    drawer: const AppDrawer(
      mode: AppMode.driver,
      selectedServiceType: OrderServiceType.intercity,
    ),
    body: _checkingActive
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DriverIntercityAction(
                key: const Key('driver_intercity_orders'),
                icon: Icons.local_taxi_outlined,
                title: AppLocalizations.of(context).driverIntercityOrders,
                subtitle: AppLocalizations.of(
                  context,
                ).driverIntercityOrdersHint,
                onTap: () => _open(
                  context,
                  AppRoutes.driverIntercityOrders,
                  widget.ordersBuilder,
                ),
              ),
              const SizedBox(height: 12),
              _DriverIntercityAction(
                key: const Key('driver_intercity_rides'),
                icon: Icons.route_outlined,
                title: AppLocalizations.of(context).driverIntercityMyRides,
                subtitle: AppLocalizations.of(
                  context,
                ).driverIntercityMyRidesHint,
                onTap: () => _open(
                  context,
                  AppRoutes.driverIntercityRides,
                  widget.ridesBuilder,
                ),
              ),
              const SizedBox(height: 12),
              _DriverIntercityAction(
                key: const Key('driver_intercity_create'),
                icon: Icons.add_road_outlined,
                title: AppLocalizations.of(context).driverIntercityCreateRide,
                subtitle: AppLocalizations.of(
                  context,
                ).driverIntercityCreateHint,
                onTap: () => _open(
                  context,
                  AppRoutes.driverIntercityCreate,
                  widget.createBuilder,
                ),
              ),
            ],
          ),
  );
}

class _DriverIntercityAction extends StatelessWidget {
  const _DriverIntercityAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      minVerticalPadding: 18,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
