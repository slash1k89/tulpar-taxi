import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

void main() {
  test('delivery normalization keeps camelCase response fields', () {
    final delivery = normalizeDeliveryData({
      'itemDescription': 'Документы',
      'recipientName': 'Алия',
      'recipientPhone': '+77000000000',
    });

    expect(delivery?['itemDescription'], 'Документы');
    expect(delivery?['recipientName'], 'Алия');
    expect(delivery?['recipientPhone'], '+77000000000');
  });

  test('delivery normalization supports transitional snake_case fields', () {
    final delivery = normalizeDeliveryData({
      'item_description': 'Посылка',
      'recipient_name': 'Марат',
      'recipient_phone': '+77770000000',
    });

    expect(delivery?['itemDescription'], 'Посылка');
    expect(delivery?['recipientName'], 'Марат');
    expect(delivery?['recipientPhone'], '+77770000000');
  });

  test('camelCase delivery values take precedence during transition', () {
    final delivery = normalizeDeliveryData({
      'recipientPhone': '+77000000000',
      'recipient_phone': '+77770000000',
    });

    expect(delivery?['recipientPhone'], '+77000000000');
  });
}
