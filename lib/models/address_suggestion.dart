class AddressSuggestion {
  final String displayName;
  final double lat;
  final double lng;
  final String? road;
  final String? houseNumber;
  final String? locality;

  AddressSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
    this.road,
    this.houseNumber,
    this.locality,
  });

  String get shortAddress {
    final street = road?.trim() ?? '';
    final house = houseNumber?.trim() ?? '';
    if (street.isNotEmpty) {
      if (house.isEmpty || _samePart(street, house)) return street;
      return '$street, $house';
    }
    return shortAddressFromDisplayName(displayName);
  }

  static String shortAddressFromDisplayName(String value) {
    final rawParts = value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (rawParts.length >= 2 && _samePart(rawParts[0], rawParts[1])) {
      return rawParts[0];
    }
    final parts = <String>[];
    for (final part in rawParts) {
      if (parts.isEmpty || !_samePart(parts.last, part)) parts.add(part);
    }
    if (parts.length < 2) return value.trim();
    final firstIsHouse = _looksLikeHouseNumber(parts[0]);
    final secondIsHouse = _looksLikeHouseNumber(parts[1]);
    if (firstIsHouse && !secondIsHouse) return '${parts[1]}, ${parts[0]}';
    if (!firstIsHouse && secondIsHouse) return '${parts[0]}, ${parts[1]}';
    return parts[0];
  }

  static String? streetFromAddressComponents(Map address) {
    for (final key in const [
      'road',
      'pedestrian',
      'residential',
      'street',
      'footway',
      'path',
    ]) {
      final value = address[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    // Формируем понятный короткий адрес из ответа OpenStreetMap
    final address = json['address'] as Map<String, dynamic>?;
    final fullName = json['display_name']?.toString() ?? '';
    String? road;
    String? houseNumber;
    String? locality;

    if (address != null) {
      road = streetFromAddressComponents(address);
      houseNumber = address['house_number']?.toString();
      locality = (address['city'] ?? address['town'] ?? address['village'])
          ?.toString();
    }

    return AddressSuggestion(
      displayName: fullName,
      lat: double.parse(json['lat'].toString()),
      lng: double.parse(json['lon'].toString()),
      road: road,
      houseNumber: houseNumber,
      locality: locality,
    );
  }

  static bool _samePart(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();

  static bool _looksLikeHouseNumber(String value) => RegExp(
    r'^(?:дом\s*)?\d+[a-zа-я]?(?:\s*[/\-]\s*\d+[a-zа-я]?)?$',
    caseSensitive: false,
  ).hasMatch(value.trim());
}
