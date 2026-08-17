import 'package:shared_preferences/shared_preferences.dart';

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
}