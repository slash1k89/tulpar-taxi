import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../screens/driver/driver_agreement_screen.dart';
import '../services/driver_agreement_service.dart';

enum AppMode { passenger, driver }

typedef AppModeChangeCallback = Future<void> Function(AppMode mode);

class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.mode,
    this.onModeChanged,
    this.userLabel,
  });

  final AppMode mode;
  final AppModeChangeCallback? onModeChanged;
  final String? userLabel;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isChangingMode = false;

  Future<void> _changeMode(bool driverMode) async {
    if (_isChangingMode || driverMode == (widget.mode == AppMode.driver)) {
      return;
    }

    setState(() => _isChangingMode = true);
    Navigator.pop(context);

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

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
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

      final agreementService = DriverAgreementService();
      var accepted = await agreementService.hasAcceptedCurrentAgreement(
        user.uid,
      );
      if (!accepted && mounted) {
        accepted =
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => DriverAgreementScreen(
                  userId: user.uid,
                  agreementService: agreementService,
                ),
              ),
            ) ??
            false;
      }
      if (!accepted || !mounted) return;

      await Navigator.pushNamed(context, AppRoutes.driverSubscription);
    } finally {
      if (mounted) setState(() => _isChangingMode = false);
    }
  }

  void _openRoute(String routeName) {
    Navigator.pop(context);
    Navigator.pushNamed(context, routeName, arguments: widget.mode);
  }

  Future<void> _signOut() async {
    Navigator.pop(context);
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    var label = widget.userLabel ?? '';
    if (widget.userLabel == null) {
      try {
        label = FirebaseAuth.instance.currentUser?.email ?? '';
      } catch (_) {
        label = '';
      }
    }
    final isDriver = widget.mode == AppMode.driver;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(isDriver ? 'Водитель' : 'Пассажир'),
            accountEmail: Text(label),
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
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Карта'),
            onTap: () => _openRoute(AppRoutes.map),
          ),
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
}

AppMode appModeFromRoute(
  BuildContext context, {
  AppMode fallback = AppMode.passenger,
}) {
  final arguments = ModalRoute.of(context)?.settings.arguments;
  return arguments is AppMode ? arguments : fallback;
}
