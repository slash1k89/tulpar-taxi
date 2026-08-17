import 'package:latlong2/latlong.dart';

class City {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double mapZoom;
  final bool isActive;

  const City({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.mapZoom,
    this.isActive = true,
  });

  LatLng get center => LatLng(latitude, longitude);
}

// Список городов (Есиль по умолчанию)
const List<City> availableCities = [
  City(
    id: 'esil',
    name: 'Есиль',
    latitude: 51.9570,
    longitude: 66.4040,
    mapZoom: 13.5,
  ),
  City(
    id: 'astana',
    name: 'Астана',
    latitude: 51.1694,
    longitude: 71.4491,
    mapZoom: 11.5,
  ),
  City(
    id: 'arkalyk',
    name: 'Аркалык',
    latitude: 50.2486,
    longitude: 66.9114,
    mapZoom: 12.5,
  ),
];
