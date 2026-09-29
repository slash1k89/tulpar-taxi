import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class WakelockGateway {
  Future<void> enable();
  Future<void> disable();
}

class PluginWakelockGateway implements WakelockGateway {
  const PluginWakelockGateway();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

bool driverTripKeepsScreenAwake(Object? status) => const {
  'accepted',
  'driver_arrived',
  'arrived',
  'in_progress',
}.contains(status?.toString());

/// Owns the single screen-awake lifecycle for an active driver trip.
///
/// Calls are serialized so a late async enable cannot overtake a completed or
/// cancelled status. Android may release the platform flag while the app is in
/// the background, so an active trip explicitly re-applies it on resume.
class DriverTripWakelockController with WidgetsBindingObserver {
  DriverTripWakelockController({WakelockGateway? gateway})
    : _gateway = gateway ?? const PluginWakelockGateway();

  final WakelockGateway _gateway;
  Future<void> _operations = Future<void>.value();
  bool _desiredEnabled = false;
  bool _appliedEnabled = false;
  bool _disposed = false;
  String _status = '';

  bool get desiredEnabled => _desiredEnabled;

  @visibleForTesting
  Future<void> get settled => _operations;

  void start(Object? status) {
    WidgetsBinding.instance.addObserver(this);
    updateStatus(status);
  }

  void updateStatus(Object? status) {
    if (_disposed) return;
    _status = status?.toString() ?? '';
    final shouldEnable = driverTripKeepsScreenAwake(status);
    _desiredEnabled = shouldEnable;
    _scheduleReconcile(
      enableReason: 'status=$_status',
      disableReason: 'status=${_status.isEmpty ? 'none' : _status}',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleLifecycleState(state);
  }

  @visibleForTesting
  void handleLifecycleState(AppLifecycleState state) {
    if (_disposed || state != AppLifecycleState.resumed || !_desiredEnabled) {
      return;
    }
    // Treat the platform state as unknown after backgrounding and re-apply.
    _appliedEnabled = false;
    _scheduleReconcile(enableReason: 'status=$_status resume');
  }

  void _scheduleReconcile({String? enableReason, String? disableReason}) {
    _operations = _operations
        .catchError((Object error) {
          if (kDebugMode) {
            debugPrint('[Wakelock] previous operation failed: $error');
          }
        })
        .then((_) async {
          if (_desiredEnabled) {
            if (_appliedEnabled) return;
            try {
              await _gateway.enable();
              _appliedEnabled = true;
              if (kDebugMode) debugPrint('[Wakelock] enable $enableReason');
            } catch (error) {
              if (kDebugMode) debugPrint('[Wakelock] enable failed: $error');
            }
            return;
          }
          if (!_appliedEnabled) return;
          try {
            await _gateway.disable();
            _appliedEnabled = false;
            if (kDebugMode) {
              debugPrint(
                '[Wakelock] disable reason=${disableReason ?? 'dispose'}',
              );
            }
          } catch (error) {
            if (kDebugMode) debugPrint('[Wakelock] disable failed: $error');
          }
        });
  }

  Future<void> dispose({String reason = 'navigation_disposed'}) async {
    if (_disposed) return;
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _desiredEnabled = false;
    _scheduleReconcile(disableReason: reason);
    await _operations;
  }
}
