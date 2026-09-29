import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/order_service_type.dart';
import '../services/app_identity_service.dart';
import '../services/user_profile_service.dart';
import '../utils/formatters.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/passenger_operational_state_resolver.dart';
import '../services/active_intercity_trip_service.dart';
import '../screens/driver/active_intercity_trip_screen.dart';

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
    this.operationalStateResolver,
    this.activeIntercityTripResolver,
  });

  final AppMode mode;
  final AppModeChangeCallback? onModeChanged;
  final String? userLabel;
  final Future<String?> Function()? phoneLoader;
  final OrderServiceType? selectedServiceType;
  final PassengerOperationalStateResolver? operationalStateResolver;
  final ActiveIntercityTripResolver? activeIntercityTripResolver;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isChangingMode = false;
  String _userLabel = '';
  late final ActiveIntercityTripResolver _activeIntercityResolver;
  ActiveIntercityTripResolution? _activeIntercity;

  @override
  void initState() {
    super.initState();
    _activeIntercityResolver =
        widget.activeIntercityTripResolver ?? ActiveIntercityTripResolver();
    _userLabel = widget.userLabel?.trim() ?? '';
    if (widget.userLabel == null) _loadPhone();
    if (widget.activeIntercityTripResolver != null ||
        AppIdentityService().isAuthenticated) {
      _loadActiveIntercityTrip();
    }
  }

  Future<ActiveIntercityTripResolution> _loadActiveIntercityTrip() async {
    final result = await _activeIntercityResolver.resolve();
    if (mounted) setState(() => _activeIntercity = result);
    return result;
  }

  void _showActiveTripUnknown() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).intercityActiveTripUnknown),
      ),
    );
  }

  void _openActiveIntercityTrip(
    NavigatorState navigator,
    ActiveIntercityTrip trip, {
    bool clearStack = false,
  }) {
    final route = MaterialPageRoute<void>(
      builder: (_) => ActiveIntercityTripScreen(trip: trip),
    );
    if (clearStack) {
      navigator.pushAndRemoveUntil(route, (_) => false);
    } else {
      navigator.push(route);
    }
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
        await (widget.operationalStateResolver ??
                PassengerOperationalStateResolver())
            .openTaxi(context, clearStack: true);
        return;
      }

      if (!AppIdentityService().isAuthenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).onboardingLoginRequired,
              ),
            ),
          );
        }
        return;
      }

      final activeIntercity = await _loadActiveIntercityTrip();
      if (!mounted) return;
      if (activeIntercity.kind == ActiveIntercityTripResolutionKind.unknown &&
          !activeIntercity.canResume) {
        _showActiveTripUnknown();
        return;
      }

      // Closing the drawer disposes this State. Keep a NavigatorState before
      // popping it and use that navigator for the entire onboarding flow.
      final navigator = Navigator.of(context);
      setState(() => _isChangingMode = true);
      navigator.pop();
      final trip = activeIntercity.trip;
      if (trip != null) {
        _openActiveIntercityTrip(navigator, trip, clearStack: true);
      } else {
        await navigator.pushNamed(AppRoutes.driverOnboarding);
      }
    } finally {
      if (mounted) setState(() => _isChangingMode = false);
    }
  }

  void _openRoute(String routeName) {
    Navigator.pop(context);
    Navigator.pushNamed(context, routeName, arguments: widget.mode);
  }

  Future<void> _openServiceSection(String routeName) async {
    final navigator = Navigator.of(context);
    if (widget.mode == AppMode.passenger && routeName == AppRoutes.map) {
      await (widget.operationalStateResolver ??
              PassengerOperationalStateResolver())
          .openTaxi(context);
      return;
    }
    if (widget.mode == AppMode.driver &&
        routeName == AppRoutes.driverIntercity) {
      final active = await _loadActiveIntercityTrip();
      if (!mounted) return;
      final trip = active.trip;
      if (trip != null) {
        navigator.pop();
        _openActiveIntercityTrip(navigator, trip);
        return;
      }
      if (active.kind == ActiveIntercityTripResolutionKind.unknown) {
        _showActiveTripUnknown();
        return;
      }
    }
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
            accountName: Text(
              isDriver
                  ? AppLocalizations.of(context).driver
                  : AppLocalizations.of(context).passenger,
            ),
            accountEmail: Text(_userLabel, key: const Key('drawer_user_label')),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.amber,
              child: Icon(Icons.person, color: Colors.black, size: 40),
            ),
            decoration: const BoxDecoration(color: Colors.black87),
          ),
          SwitchListTile(
            key: const Key('drawer_driver_mode_switch'),
            title: Text(
              AppLocalizations.of(context).onboardingDriverMode,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              isDriver
                  ? AppLocalizations.of(context).drawerEnabled
                  : AppLocalizations.of(context).drawerDisabled,
            ),
            secondary: Icon(
              Icons.local_taxi,
              color: isDriver ? Colors.amber : Colors.grey,
            ),
            value: isDriver,
            activeThumbColor: Colors.amber,
            onChanged: _isChangingMode ? null : _changeMode,
          ),
          const Divider(),
          if (isDriver && _activeIntercity?.trip != null)
            ListTile(
              key: const Key('drawer_continue_intercity_trip'),
              leading: const Icon(Icons.navigation, color: Colors.amber),
              title: Text(
                AppLocalizations.of(context).intercityContinueActiveTrip,
              ),
              onTap: () {
                final trip = _activeIntercity?.trip;
                if (trip == null) return;
                final navigator = Navigator.of(context);
                navigator.pop();
                _openActiveIntercityTrip(navigator, trip);
              },
            ),
          if (isDriver) ...[
            _serviceTile(
              type: OrderServiceType.city,
              routeName: AppRoutes.driverTaxi,
              title: AppLocalizations.of(context).taxiAndDelivery,
            ),
            _serviceTile(
              type: OrderServiceType.intercity,
              routeName: AppRoutes.driverIntercity,
            ),
          ] else ...[
            _serviceTile(
              type: OrderServiceType.city,
              routeName: AppRoutes.map,
              title: AppLocalizations.of(context).mapRequestTaxi,
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
            title: Text(AppLocalizations.of(context).drawerHistory),
            onTap: () => _openRoute(AppRoutes.history),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts),
            title: Text(AppLocalizations.of(context).profileSettingsTitle),
            onTap: () => _openRoute(AppRoutes.profile),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: Text(
              AppLocalizations.of(context).drawerSignOut,
              style: const TextStyle(color: Colors.red),
            ),
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
      title: Text(title ?? type.localizedTitle(AppLocalizations.of(context))),
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
