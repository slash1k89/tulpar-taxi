import 'package:shared_preferences/shared_preferences.dart';

import '../models/city.dart';
import 'tulpar_api_client.dart';

class CityService {
  static const String _key = 'selected_city_id';

  // Сохранить город
  static Future<void> setSelectedCity(String cityId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, cityId);
  }

  // Получить сохраненный город (по умолчанию 'esil')
  static Future<String> getSelectedCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'esil';
  }

  static Future<City> getSelectedCityDetails() async =>
      cityById(await getSelectedCity());

  static Future<List<City>> getEnabledCities({TulparApiClient? client}) async {
    final api = client ?? TulparApiClient();
    try {
      final rows = await api.getEnabledCities();
      return rows
          .map((row) {
            final id = row['id']?.toString() ?? '';
            final fallback = cityById(id);
            double number(String key) => (row[key] as num).toDouble();
            return City(
              id: id,
              name: row['name_ru']?.toString() ?? fallback.name,
              nameKk: row['name_kk']?.toString(),
              nameEn: row['name_en']?.toString(),
              latitude: number('center_lat'),
              longitude: number('center_lng'),
              mapZoom: fallback.mapZoom,
              region: fallback.region,
              bounds: id == 'esil'
                  ? fallback.bounds
                  : CityBounds(
                      south: number('bbox_south'),
                      west: number('bbox_west'),
                      north: number('bbox_north'),
                      east: number('bbox_east'),
                    ),
            );
          })
          .toList(growable: false);
    } finally {
      if (client == null) api.close();
    }
  }
}
