import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/order_service_type.dart';
import '../services/app_identity_service.dart';
import '../services/user_profile_service.dart';
import '../utils/formatters.dart';

enum AppMode { passenger, driver }

typedef AppModeChangeCallback = Future<void> Function(AppMode mode);

class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.mode,
    this.onModeChanged,
    this.userLabel,
    this.phoneLoader,
    this.selectedServiceType,
  });

  final AppMode mode;
  final AppModeChangeCallback? onModeChanged;
  final String? userLabel;
  final Future<String?> Function()? phoneLoader;
  final OrderServiceType? selectedServiceType;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isChangingMode = false;
  String _userLabel = '';

  @override
  void initState() {
    super.initState();
    _userLabel = widget.userLabel?.trim() ?? '';
    if (widget.userLabel == null) _loadPhone();
  }

  Future<void> _loadPhone() async {
    try {
      final phone = await (widget.phoneLoader ?? _loadCurrentUserPhone)();
      if (!mounted) return;
      setState(() => _userLabel = formatRuPhoneForDisplay(phone ?? ''));
    } catch (_) {
      if (mounted) setState(() => _userLabel = '');
    }
  }

  Future<String?> _loadCurrentUserPhone() async {
    final userId = AppIdentityService().currentUserId;
    if (userId == null || userId.isEmpty) return null;
    final profile = await FirebaseUserProfileRepository().load(userId);
    return profile?.phone;
  }

  Future<void> _changeMode(bool driverMode) async {
    if (_isChangingMode || driverMode == (widget.mode == AppMode.driver)) {
      return;
    }

    try {
      final nextMode = driverMode ? AppMode.driver : AppMode.passenger;
      if (widget.onModeChanged != null) {
        await widget.onModeChanged!(nextMode);
        return;
      }

      if (nextMode == AppMode.passenger) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.map,
          (route) => false,
        );
        return;
      }

      if (!AppIdentityService().isAuthenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Войдите в аккаунт, чтобы включить режим водителя.',
              ),
            ),
          );
        }
        return;
      }

      // Closing the drawer disposes this State. Keep a NavigatorState before
      // popping it and use that navigator for the entire onboarding flow.
      final navigator = Navigator.of(context);
      setState(() => _isChangingMode = true);
      navigator.pop();

      await navigator.pushNamed(AppRoutes.driverOnboarding);
    } finally {
      if (mounted) setState(() => _isChangingMode = false);
    }
  }

  void _openRoute(String routeName) {
    Navigator.pop(context);
    Navigator.pushNamed(context, routeName, arguments: widget.mode);
  }

  void _openServiceSection(String routeName) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pushReplacementNamed(routeName);
  }

  Future<void> _signOut() async {
    Navigator.pop(context);
    try {
      await AppIdentityService().signOut();
    } catch (_) {
      // TulparAuthController clears the local session even if logout delivery
      // fails, so the app must still leave authenticated screens.
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.mode == AppMode.driver;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(isDriver ? 'Водитель' : 'Пассажир'),
            accountEmail: Text(_userLabel, key: const Key('drawer_user_label')),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.amber,
              child: Icon(Icons.person, color: Colors.black, size: 40),
            ),
            decoration: const BoxDecoration(color: Colors.black87),
          ),
          SwitchListTile(
            key: const Key('drawer_driver_mode_switch'),
            title: const Text(
              'Режим водителя',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(isDriver ? 'Включен' : 'Выключен'),
            secondary: Icon(
              Icons.local_taxi,
              color: isDriver ? Colors.amber : Colors.grey,
            ),
            value: isDriver,
            activeThumbColor: Colors.amber,
            onChanged: _isChangingMode ? null : _changeMode,
          ),
          const Divider(),
          if (isDriver) ...[
            _serviceTile(
              type: OrderServiceType.city,
              routeName: AppRoutes.driverTaxi,
              title: 'Такси и доставка',
            ),
            _serviceTile(
              type: OrderServiceType.intercity,
              routeName: AppRoutes.driverIntercity,
            ),
          ] else ...[
            _serviceTile(
              type: OrderServiceType.city,
              routeName: AppRoutes.map,
              title: 'Заказать такси',
            ),
            _serviceTile(
              type: OrderServiceType.delivery,
              routeName: AppRoutes.delivery,
            ),
            _serviceTile(
              type: OrderServiceType.intercity,
              routeName: AppRoutes.intercity,
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('История заказов'),
            onTap: () => _openRoute(AppRoutes.history),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts),
            title: const Text('Профиль и настройки'),
            onTap: () => _openRoute(AppRoutes.profile),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Выйти', style: TextStyle(color: Colors.red)),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }

  Widget _serviceTile({
    required OrderServiceType type,
    required String routeName,
    String? title,
    String? subtitle,
  }) {
    return ListTile(
      key: Key('drawer_service_${type.apiValue}'),
      leading: Icon(type.icon),
      title: Text(title ?? type.title),
      subtitle: subtitle == null ? null : Text(subtitle),
      selected: widget.selectedServiceType == type,
      onTap: () => _openServiceSection(routeName),
    );
  }
}

AppMode appModeFromRoute(
  BuildContext context, {
  AppMode fallback = AppMode.passenger,
}) {
  final arguments = ModalRoute.of(context)?.settings.arguments;
  return arguments is AppMode ? arguments : fallback;
}
