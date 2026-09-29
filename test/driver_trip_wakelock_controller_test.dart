import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/driver_trip_wakelock_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('active driver statuses keep wakelock on across rebuilds', () async {
    final gateway = _FakeWakelockGateway();
    final controller = DriverTripWakelockController(gateway: gateway);
    controller.start('accepted');
    await controller.settled;
    expect(gateway.enabled, isTrue);

    for (final status in ['accepted', 'arrived', 'in_progress']) {
      controller.updateStatus(status);
      await controller.settled;
      expect(gateway.enabled, isTrue);
    }
    expect(gateway.enableCalls, 1);
    await controller.dispose();
    expect(gateway.enabled, isFalse);
  });

  test('resume re-applies wakelock only for an active trip', () async {
    final gateway = _FakeWakelockGateway();
    final controller = DriverTripWakelockController(gateway: gateway);
    controller.start('in_progress');
    await controller.settled;
    controller.handleLifecycleState(AppLifecycleState.paused);
    controller.handleLifecycleState(AppLifecycleState.resumed);
    await controller.settled;
    expect(gateway.enableCalls, 2);

    controller.updateStatus('completed');
    await controller.settled;
    controller.handleLifecycleState(AppLifecycleState.resumed);
    await controller.settled;
    expect(gateway.enabled, isFalse);
    expect(gateway.enableCalls, 2);
    await controller.dispose();
  });

  for (final status in ['completed', 'cancelled', 'expired']) {
    test('$status releases wakelock', () async {
      final gateway = _FakeWakelockGateway();
      final controller = DriverTripWakelockController(gateway: gateway);
      controller.start('accepted');
      await controller.settled;
      controller.updateStatus(status);
      await controller.settled;
      expect(gateway.enabled, isFalse);
      expect(gateway.disableCalls, 1);
      await controller.dispose();
    });
  }

  test('late enable cannot overtake completion', () async {
    final enableGate = Completer<void>();
    final gateway = _FakeWakelockGateway(enableGate: enableGate);
    final controller = DriverTripWakelockController(gateway: gateway);
    controller.start('accepted');
    await Future<void>.delayed(Duration.zero);
    controller.updateStatus('completed');
    enableGate.complete();
    await controller.settled;
    expect(gateway.enabled, isFalse);
    expect(gateway.disableCalls, 1);
    await controller.dispose();
  });

  test('disposing active navigation releases wakelock', () async {
    final gateway = _FakeWakelockGateway();
    final controller = DriverTripWakelockController(gateway: gateway);
    controller.start('in_progress');
    await controller.settled;
    await controller.dispose(reason: 'trip_finished');
    expect(gateway.enabled, isFalse);
    expect(gateway.disableCalls, 1);
  });
}

class _FakeWakelockGateway implements WakelockGateway {
  _FakeWakelockGateway({this.enableGate});

  final Completer<void>? enableGate;
  bool enabled = false;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enable() async {
    enableCalls++;
    await enableGate?.future;
    enabled = true;
  }

  @override
  Future<void> disable() async {
    disableCalls++;
    enabled = false;
  }
}
