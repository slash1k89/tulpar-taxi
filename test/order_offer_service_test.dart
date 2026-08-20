import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/driver_order_diagnostics.dart';
import 'package:taxi_esil/services/order_offer_service.dart';
import 'package:taxi_esil/services/order_price_service.dart';

void main() {
  test('legacy order price is treated as passenger price', () {
    expect(OrderPriceService.passengerPrice({'price': 600}), 600);
  });

  test('agreed price is preferred for display', () {
    expect(
      OrderPriceService.displayedPrice({
        'price': 700,
        'passengerPrice': 600,
        'agreedPrice': 700,
      }),
      700,
    );
  });

  test('driver offer must be higher than passenger price', () {
    expect(
      () => OrderOfferService.validateOfferPrice(600, passengerPrice: 600),
      throwsA(isA<OrderOfferException>()),
    );
  });

  test('driver offer accepts a higher integer price', () {
    expect(
      () => OrderOfferService.validateOfferPrice(700, passengerPrice: 600),
      returnsNormally,
    );
  });

  test('driver offer rejects the technical maximum overflow', () {
    expect(
      () => OrderOfferService.validateOfferPrice(
        OrderPriceService.maximumOrderPrice + 1,
        passengerPrice: 600,
      ),
      throwsA(isA<OrderOfferException>()),
    );
  });

  test('active binding pointing to completed order is stale', () {
    expect(
      DriverOrderDiagnosticSnapshot.classifyActiveBinding(
        bindingExists: true,
        linkedOrderWasChecked: true,
        linkedOrderExists: true,
        linkedOrderStatus: 'completed',
      ),
      isTrue,
    );
  });

  test('active binding pointing to cancelled order is stale', () {
    expect(
      DriverOrderDiagnosticSnapshot.classifyActiveBinding(
        bindingExists: true,
        linkedOrderWasChecked: true,
        linkedOrderExists: true,
        linkedOrderStatus: 'cancelled',
      ),
      isTrue,
    );
  });

  test('active binding pointing to missing order is stale', () {
    expect(
      DriverOrderDiagnosticSnapshot.classifyActiveBinding(
        bindingExists: true,
        linkedOrderWasChecked: true,
        linkedOrderExists: false,
        linkedOrderStatus: null,
      ),
      isTrue,
    );
  });

  test('active binding pointing to in-progress order is not stale', () {
    expect(
      DriverOrderDiagnosticSnapshot.classifyActiveBinding(
        bindingExists: true,
        linkedOrderWasChecked: true,
        linkedOrderExists: true,
        linkedOrderStatus: 'in_progress',
      ),
      isFalse,
    );
  });
}
