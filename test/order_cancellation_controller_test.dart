import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/active_order_service.dart';
import 'package:taxi_esil/services/order_cancellation_controller.dart';

void main() {
  testWidgets('returns to the clean map three seconds after cancellation', (
    tester,
  ) async {
    final messageClosed = Completer<void>();
    var cleanupCount = 0;
    var navigationCount = 0;
    var shownMessage = '';
    final controller = OrderCancellationController(
      onCleanup: () => cleanupCount++,
      onShowMessage: (message) {
        shownMessage = message;
        return messageClosed.future;
      },
      onNavigate: () => navigationCount++,
      onError: (_, _) {},
    );
    addTearDown(controller.dispose);

    expect(await controller.cancel(() async {}), isTrue);
    expect(cleanupCount, 1);
    expect(shownMessage, 'Заказ отменён');

    await tester.pump(const Duration(milliseconds: 2999));
    expect(navigationCount, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(navigationCount, 1);
  });

  testWidgets('dismissed cancellation message returns immediately', (
    tester,
  ) async {
    final messageClosed = Completer<void>();
    var navigationCount = 0;
    final controller = OrderCancellationController(
      onCleanup: () {},
      onShowMessage: (_) => messageClosed.future,
      onNavigate: () => navigationCount++,
      onError: (_, _) {},
    );
    addTearDown(controller.dispose);

    await controller.cancel(() async {});
    messageClosed.complete();
    await tester.pump();

    expect(navigationCount, 1);
  });

  testWidgets('dispose cancels delayed and message-driven navigation', (
    tester,
  ) async {
    final messageClosed = Completer<void>();
    var navigationCount = 0;
    final controller = OrderCancellationController(
      onCleanup: () {},
      onShowMessage: (_) => messageClosed.future,
      onNavigate: () => navigationCount++,
      onError: (_, _) {},
    );

    controller.handleObservedCancellation(requestedLocally: false);
    controller.dispose();
    messageClosed.complete();
    await tester.pump(const Duration(seconds: 3));

    expect(navigationCount, 0);
  });

  testWidgets('double cancellation and duplicate events navigate only once', (
    tester,
  ) async {
    final firebaseOperation = Completer<void>();
    final messageClosed = Completer<void>();
    var firebaseCalls = 0;
    var messageCount = 0;
    var navigationCount = 0;
    final controller = OrderCancellationController(
      onCleanup: () {},
      onShowMessage: (_) {
        messageCount++;
        return messageClosed.future;
      },
      onNavigate: () => navigationCount++,
      onError: (_, _) {},
    );
    addTearDown(controller.dispose);

    final firstAttempt = controller.cancel(() {
      firebaseCalls++;
      return firebaseOperation.future;
    });
    final secondAttempt = await controller.cancel(() async {
      firebaseCalls++;
    });
    expect(secondAttempt, isFalse);
    expect(firebaseCalls, 1);

    firebaseOperation.complete();
    expect(await firstAttempt, isTrue);
    controller.handleObservedCancellation(requestedLocally: true);
    messageClosed.complete();
    await tester.pump(const Duration(seconds: 3));

    expect(messageCount, 1);
    expect(navigationCount, 1);
  });

  testWidgets('Firebase error does not show success or navigate', (
    tester,
  ) async {
    var cleanupCount = 0;
    var messageCount = 0;
    var errorCount = 0;
    var navigationCount = 0;
    final controller = OrderCancellationController(
      onCleanup: () => cleanupCount++,
      onShowMessage: (_) {
        messageCount++;
        return Future<void>.value();
      },
      onNavigate: () => navigationCount++,
      onError: (_, _) => errorCount++,
    );
    addTearDown(controller.dispose);

    final result = await controller.cancel(
      () => Future<void>.error(Exception('permission-denied')),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(result, isFalse);
    expect(cleanupCount, 0);
    expect(messageCount, 0);
    expect(errorCount, 1);
    expect(navigationCount, 0);
    expect(controller.isCancelling, isFalse);
  });

  test('cancelled order cannot be restored as active', () {
    expect(activeOrderStatuses.contains('cancelled'), isFalse);
    expect(activeOrderStatuses.contains('completed'), isFalse);
    expect(activeOrderStatuses.contains('searching'), isTrue);
  });
}
