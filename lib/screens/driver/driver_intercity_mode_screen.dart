import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/order_service_type.dart';
import '../../widgets/app_drawer.dart';

class DriverIntercityModeScreen extends StatelessWidget {
  const DriverIntercityModeScreen({
    super.key,
    this.ordersBuilder,
    this.ridesBuilder,
    this.createBuilder,
  });

  final WidgetBuilder? ordersBuilder;
  final WidgetBuilder? ridesBuilder;
  final WidgetBuilder? createBuilder;

  void _open(BuildContext context, String route, WidgetBuilder? builder) {
    if (builder != null) {
      Navigator.push(context, MaterialPageRoute(builder: builder));
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Межгород')),
    drawer: const AppDrawer(
      mode: AppMode.driver,
      selectedServiceType: OrderServiceType.intercity,
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DriverIntercityAction(
          key: const Key('driver_intercity_orders'),
          icon: Icons.local_taxi_outlined,
          title: 'Заказы пассажиров',
          subtitle: 'Обычные междугородние заказы',
          onTap: () =>
              _open(context, AppRoutes.driverIntercityOrders, ordersBuilder),
        ),
        const SizedBox(height: 12),
        _DriverIntercityAction(
          key: const Key('driver_intercity_rides'),
          icon: Icons.route_outlined,
          title: 'Мои поездки',
          subtitle: 'Опубликованные попутки и бронирования',
          onTap: () =>
              _open(context, AppRoutes.driverIntercityRides, ridesBuilder),
        ),
        const SizedBox(height: 12),
        _DriverIntercityAction(
          key: const Key('driver_intercity_create'),
          icon: Icons.add_road_outlined,
          title: 'Создать поездку',
          subtitle: 'Опубликовать места для попутчиков',
          onTap: () =>
              _open(context, AppRoutes.driverIntercityCreate, createBuilder),
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
