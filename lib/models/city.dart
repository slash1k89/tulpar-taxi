import 'package:latlong2/latlong.dart';

class City {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double mapZoom;
  final String region;
  final CityBounds bounds;
  final bool isActive;

  const City({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.mapZoom,
    required this.region,
    required this.bounds,
    this.isActive = true,
  });

  LatLng get center => LatLng(latitude, longitude);

  bool contains(LatLng point) => bounds.contains(point);
}

class CityBounds {
  const CityBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(LatLng point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;

  String get nominatimViewBox => '$west,$north,$east,$south';
}

// Список городов (Есиль по умолчанию)
const List<City> availableCities = [
  City(
    id: 'esil',
    name: 'Есиль',
    latitude: 51.9570,
    longitude: 66.4040,
    mapZoom: 13.5,
    region: 'Акмолинская область',
    bounds: CityBounds(south: 51.90, west: 66.31, north: 52.02, east: 66.50),
  ),
  City(
    id: 'astana',
    name: 'Астана',
    latitude: 51.1694,
    longitude: 71.4491,
    mapZoom: 11.5,
    region: 'город республиканского значения',
    bounds: CityBounds(south: 50.90, west: 71.15, north: 51.35, east: 71.75),
  ),
  City(
    id: 'arkalyk',
    name: 'Аркалык',
    latitude: 50.2486,
    longitude: 66.9114,
    mapZoom: 12.5,
    region: 'Костанайская область',
    bounds: CityBounds(south: 50.16, west: 66.75, north: 50.34, east: 67.08),
  ),
];

City cityById(String? id) => availableCities.firstWhere(
  (city) => city.id == id,
  orElse: () => availableCities.first,
);
