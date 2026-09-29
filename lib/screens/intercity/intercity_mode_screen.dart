import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/order_service_type.dart';
import '../../widgets/app_drawer.dart';
import '../../l10n/generated/app_localizations.dart';

class IntercityModeScreen extends StatelessWidget {
  const IntercityModeScreen({
    super.key,
    this.orderBuilder,
    this.rideSearchBuilder,
  });

  final WidgetBuilder? orderBuilder;
  final WidgetBuilder? rideSearchBuilder;

  void _open(
    BuildContext context, {
    required String route,
    WidgetBuilder? builder,
  }) {
    if (builder != null) {
      Navigator.push(context, MaterialPageRoute(builder: builder));
      return;
    }
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).serviceIntercity)),
    drawer: const AppDrawer(
      mode: AppMode.passenger,
      selectedServiceType: OrderServiceType.intercity,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ModeCard(
            key: const Key('intercity_order_mode'),
            icon: Icons.directions_car_filled_outlined,
            title: AppLocalizations.of(context).intercityOrderCar,
            subtitle: AppLocalizations.of(context).intercityOrderCarHint,
            onTap: () => _open(
              context,
              route: AppRoutes.intercityOrder,
              builder: orderBuilder,
            ),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            key: const Key('intercity_rideshare_mode'),
            icon: Icons.people_alt_outlined,
            title: AppLocalizations.of(context).intercityFindRide,
            subtitle: AppLocalizations.of(context).intercityFindRideHint,
            onTap: () => _open(
              context,
              route: AppRoutes.intercityRideSearch,
              builder: rideSearchBuilder,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            key: const Key('intercity_my_bookings'),
            leading: const Icon(Icons.event_seat_outlined),
            title: Text(AppLocalizations.of(context).intercityMyBookings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.intercityBookings),
          ),
          ListTile(
            key: const Key('intercity_my_requests'),
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(AppLocalizations.of(context).intercityLookingForRide),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.intercityRequests),
          ),
        ],
      ),
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
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
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
