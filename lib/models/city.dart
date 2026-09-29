import 'package:latlong2/latlong.dart';

class City {
  final String id;
  final String name;
  final String? nameKk;
  final String? nameEn;
  final double latitude;
  final double longitude;
  final double mapZoom;
  final String region;
  final CityBounds bounds;
  final bool isActive;

  const City({
    required this.id,
    required this.name,
    this.nameKk,
    this.nameEn,
    required this.latitude,
    required this.longitude,
    required this.mapZoom,
    required this.region,
    required this.bounds,
    this.isActive = true,
  });

  LatLng get center => LatLng(latitude, longitude);

  String localizedName(String languageCode) => switch (languageCode) {
    'kk' => nameKk ?? name,
    'en' => nameEn ?? name,
    _ => name,
  };

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

// UI fallback derived from verified OSM place nodes/polygons. The backend
// cities table remains authoritative for enabled cities and order acceptance.
const List<City> availableCities = [
  City(
    id: 'esil',
    name: 'Есиль',
    nameKk: 'Есіл',
    nameEn: 'Esil',
    latitude: 51.9607263,
    longitude: 66.404878,
    mapZoom: 13.5,
    region: 'Акмолинская область',
    // Preserve the existing Esil selection envelope; reverse geocoding still
    // verifies settlement for picked points. Import uses the OSM place polygon.
    bounds: CityBounds(south: 51.90, west: 66.31, north: 52.02, east: 66.50),
  ),
  City(
    id: 'atbasar',
    name: 'Атбасар',
    nameKk: 'Атбасар',
    nameEn: 'Atbasar',
    latitude: 51.8097369,
    longitude: 68.3573356,
    mapZoom: 13.5,
    region: '',
    bounds: CityBounds(
      south: 51.7651318,
      west: 68.3030282,
      north: 51.8431278,
      east: 68.3833996,
    ),
  ),
  City(
    id: 'makinsk',
    name: 'Макинск',
    nameKk: 'Макинск',
    nameEn: 'Makinsk',
    latitude: 52.63287,
    longitude: 70.418213,
    mapZoom: 13.5,
    region: '',
    bounds: CityBounds(
      south: 52.6090679,
      west: 70.3864002,
      north: 52.6594917,
      east: 70.4495448,
    ),
  ),
  City(
    id: 'ereymentau',
    name: 'Ерейментау',
    nameKk: 'Ерейментау',
    nameEn: 'Ereymentaw',
    latitude: 51.619881,
    longitude: 73.103348,
    mapZoom: 13.5,
    region: '',
    bounds: CityBounds(
      south: 51.5946863,
      west: 73.0733523,
      north: 51.6390267,
      east: 73.1911978,
    ),
  ),
  City(
    id: 'rudny',
    name: 'Рудный',
    nameKk: 'Рудный',
    nameEn: 'Rudny',
    latitude: 52.964458,
    longitude: 63.133488,
    mapZoom: 12.5,
    region: '',
    bounds: CityBounds(
      south: 52.9351723,
      west: 62.966529,
      north: 53.0856565,
      east: 63.2783059,
    ),
  ),
  City(
    id: 'lisakovsk',
    name: 'Лисаковск',
    nameKk: 'Лисаковск',
    nameEn: 'Lisakovsk',
    latitude: 52.545864,
    longitude: 62.489201,
    mapZoom: 13.5,
    region: '',
    bounds: CityBounds(
      south: 52.5207134,
      west: 62.4478187,
      north: 52.57808,
      east: 62.5816138,
    ),
  ),
  City(
    id: 'karkaralinsk',
    name: 'Каркаралинск',
    nameKk: 'Қарқаралы',
    nameEn: 'Qarqaraly',
    latitude: 49.4124087,
    longitude: 75.4704514,
    mapZoom: 14.0,
    region: '',
    bounds: CityBounds(
      south: 49.4000745,
      west: 75.4522265,
      north: 49.4294928,
      east: 75.5044719,
    ),
  ),
  City(
    id: 'shchuchinsk',
    name: 'Щучинск',
    nameKk: 'Щучинск',
    nameEn: 'Shchuchinsk',
    latitude: 52.9387457,
    longitude: 70.1857634,
    mapZoom: 13.0,
    region: '',
    bounds: CityBounds(
      south: 52.9083282,
      west: 70.1326921,
      north: 52.9794398,
      east: 70.3022002,
    ),
  ),
  City(
    id: 'arkalyk',
    name: 'Аркалык',
    nameKk: 'Арқалық',
    nameEn: 'Arkalyk',
    latitude: 50.253281,
    longitude: 66.914993,
    mapZoom: 13.0,
    region: 'Костанайская область',
    bounds: CityBounds(
      south: 50.2290889,
      west: 66.8630719,
      north: 50.2880231,
      east: 66.963129,
    ),
  ),
  City(
    id: 'zhitikara',
    name: 'Житикара',
    nameKk: 'Жітіқара',
    nameEn: 'Jitiqara',
    latitude: 52.1905261,
    longitude: 61.2047527,
    mapZoom: 13.5,
    region: '',
    bounds: CityBounds(
      south: 52.1719315,
      west: 61.1605024,
      north: 52.2084482,
      east: 61.2431573,
    ),
  ),
  City(
    id: 'shalkar',
    name: 'Шалкар',
    nameKk: 'Шалқар',
    nameEn: 'Şalqar',
    latitude: 47.8273018,
    longitude: 59.6159216,
    mapZoom: 13.5,
    region: '',
    bounds: CityBounds(
      south: 47.8017028,
      west: 59.5917017,
      north: 47.8561917,
      east: 59.6527745,
    ),
  ),
  City(
    id: 'aralsk',
    name: 'Аральск',
    nameKk: 'Арал',
    nameEn: 'Aral',
    latitude: 46.797985,
    longitude: 61.661221,
    mapZoom: 13.5,
    region: '',
    bounds: CityBounds(
      south: 46.7818563,
      west: 61.6261836,
      north: 46.833313,
      east: 61.7097953,
    ),
  ),
  City(
    id: 'ekibastuz',
    name: 'Экибастуз',
    nameKk: 'Екібастұз',
    nameEn: 'Ekibastuz',
    latitude: 51.7275817,
    longitude: 75.3288511,
    mapZoom: 13.0,
    region: '',
    bounds: CityBounds(
      south: 51.6901329,
      west: 75.2707853,
      north: 51.7600127,
      east: 75.3642433,
    ),
  ),
];

City cityById(String? id) => availableCities.firstWhere(
  (city) => city.id == id,
  orElse: () => availableCities.first,
);
