class AddressSuggestion {
  final String displayName;
  final double lat;
  final double lng;

  AddressSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
  });

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    // Формируем понятный короткий адрес из ответа OpenStreetMap
    final address = json['address'] as Map<String, dynamic>?;
    String name = json['display_name'] ?? '';

    if (address != null) {
      final road = address['road'] ?? address['pedestrian'] ?? address['suburb'] ?? '';
      final houseNumber = address['house_number'] ?? '';
      if (road.isNotEmpty) {
        name = houseNumber.isNotEmpty ? '$road, $houseNumber' : road;
      }
    }

    return AddressSuggestion(
      displayName: name,
      lat: double.parse(json['lat'].toString()),
      lng: double.parse(json['lon'].toString()),
    );
  }
}