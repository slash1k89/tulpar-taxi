import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/models/address_suggestion.dart';

void main() {
  test('shortAddress uses structured street and house number', () {
    final address = AddressSuggestion.fromJson({
      'display_name':
          'улица Абая, 15, Есиль, Акмолинская область, 020900, Казахстан',
      'lat': '51.95',
      'lon': '66.40',
      'address': {
        'road': 'улица Абая',
        'house_number': '15',
        'town': 'Есиль',
        'state': 'Акмолинская область',
        'postcode': '020900',
        'country': 'Казахстан',
      },
    });

    expect(address.shortAddress, 'улица Абая, 15');
    expect(address.shortAddress, isNot(contains('область')));
    expect(address.shortAddress, isNot(contains('Казахстан')));
    expect(address.locality, 'Есиль');
  });

  test('shortAddress has a centralized fallback for display names', () {
    final address = AddressSuggestion(
      displayName: 'ул. Абая, 15, Есиль, Акмолинская область, Казахстан',
      lat: 51.95,
      lng: 66.40,
    );

    expect(address.shortAddress, 'ул. Абая, 15');
  });

  test('road and house number produce street then house', () {
    final address = AddressSuggestion(
      displayName: '15, Абая, Есиль',
      lat: 51.95,
      lng: 66.4,
      road: 'Абая',
      houseNumber: '15',
    );
    expect(address.shortAddress, 'Абая, 15');
    expect(address.shortAddress, isNot('15'));
  });

  test('road without house number stays readable', () {
    final address = AddressSuggestion(
      displayName: 'Абая, Есиль',
      lat: 51.95,
      lng: 66.4,
      road: 'Абая',
    );
    expect(address.shortAddress, 'Абая');
  });

  test('street-like fallback component is used with house number', () {
    final address = AddressSuggestion.fromJson({
      'display_name': '15, Пешеходная улица, Есиль',
      'lat': '51.95',
      'lon': '66.4',
      'address': {'pedestrian': 'Пешеходная улица', 'house_number': '15'},
    });
    expect(address.shortAddress, 'Пешеходная улица, 15');
  });

  test('house-first Nominatim display name is reordered', () {
    expect(
      AddressSuggestion.shortAddressFromDisplayName('15, Абая, Есиль'),
      'Абая, 15',
    );
  });

  test('missing street and house uses the existing safe fallback', () {
    expect(
      AddressSuggestion.shortAddressFromDisplayName('Есиль, Казахстан'),
      'Есиль',
    );
    expect(AddressSuggestion.shortAddressFromDisplayName(''), '');
  });

  test('formatter does not duplicate street or house parts', () {
    expect(
      AddressSuggestion.shortAddressFromDisplayName('Абая, Абая, Есиль'),
      'Абая',
    );
    expect(
      AddressSuggestion.shortAddressFromDisplayName('15, 15, Есиль'),
      '15',
    );
    final structured = AddressSuggestion(
      displayName: 'Абая, Есиль',
      lat: 51.95,
      lng: 66.4,
      road: 'Абая',
      houseNumber: 'Абая',
    );
    expect(structured.shortAddress, 'Абая');
  });
}
