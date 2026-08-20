class OrderPriceService {
  const OrderPriceService._();

  static const int maximumOrderPrice = 1000000;

  static int? readInteger(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return null;
  }

  static int? passengerPrice(Map<String, dynamic> order) {
    return readInteger(order['passengerPrice']) ?? readInteger(order['price']);
  }

  static int? agreedPrice(Map<String, dynamic> order) {
    return readInteger(order['agreedPrice']);
  }

  static int? displayedPrice(Map<String, dynamic> order) {
    return agreedPrice(order) ??
        readInteger(order['price']) ??
        passengerPrice(order);
  }
}
