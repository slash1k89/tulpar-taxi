import 'dart:ui';

class AddressLabelService {
  const AddressLabelService._();

  static String format(Object? value, Locale locale) {
    final raw = _localizedValue(value, locale);
    if (raw.isEmpty || locale.languageCode != 'en') return raw;
    if (!_containsCyrillic(raw)) return raw;
    return _transliterate(_translateKnownPlaces(raw));
  }

  static String fromOrder(
    Map<String, dynamic> order,
    Locale locale,
    List<String> keys,
  ) {
    if (locale.languageCode == 'en') {
      for (final key in keys) {
        for (final variant in _localizedKeyVariants(key, 'en')) {
          final value = order[variant]?.toString().trim() ?? '';
          if (value.isNotEmpty) return format(value, locale);
        }
      }
    } else if (locale.languageCode == 'kk') {
      for (final key in keys) {
        for (final variant in _localizedKeyVariants(key, 'kk')) {
          final value = order[variant]?.toString().trim() ?? '';
          if (value.isNotEmpty) return value;
        }
      }
    }
    for (final key in keys) {
      final value = order[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return format(value, locale);
      }
    }
    return '';
  }

  static String _localizedValue(Object? value, Locale locale) {
    if (value is! Map) return value?.toString().trim() ?? '';
    final map = Map<String, dynamic>.from(value);
    final language = locale.languageCode;
    final preferred = language == 'en'
        ? const [
            'name_en',
            'nameEn',
            'address_en',
            'addressEn',
            'display_name_en',
            'displayNameEn',
          ]
        : language == 'kk'
        ? const [
            'name_kk',
            'nameKk',
            'address_kk',
            'addressKk',
            'display_name_kk',
            'displayNameKk',
          ]
        : const [
            'name_ru',
            'nameRu',
            'address_ru',
            'addressRu',
            'display_name_ru',
            'displayNameRu',
          ];
    for (final key in preferred) {
      final candidate = map[key]?.toString().trim() ?? '';
      if (candidate.isNotEmpty) return candidate;
    }
    if (language == 'en') {
      for (final key in const [
        'name',
        'address',
        'displayName',
        'display_name',
        'label',
      ]) {
        final candidate = map[key]?.toString().trim() ?? '';
        if (candidate.isNotEmpty && !_containsCyrillic(candidate)) {
          return candidate;
        }
      }
    }
    for (final key in const [
      'address',
      'name',
      'displayName',
      'display_name',
      'label',
    ]) {
      final candidate = map[key]?.toString().trim() ?? '';
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }

  static Iterable<String> _localizedKeyVariants(String key, String language) {
    final snake = key.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
    final suffix = language[0].toUpperCase() + language.substring(1);
    return ['$key$suffix', '${key}_$language', '${snake}_$language'];
  }

  static bool _containsCyrillic(String value) =>
      RegExp(r'[\u0400-\u04FF]').hasMatch(value);

  static String _translateKnownPlaces(String value) {
    var result = value;
    const replacements = <String, String>{
      'железнодорожный вокзал': 'Railway Station',
      'жд вокзал': 'Railway Station',
      'ж/д вокзал': 'Railway Station',
      'автовокзал': 'Bus Station',
      'автостанция': 'Bus Station',
      'вокзал': 'Railway Station',
      'отдел полиции': 'Police Department',
      'полиция': 'Police',
      'аурухана': 'Hospital',
      'районная больница': 'District Hospital',
      'больница': 'Hospital',
      'поликлиника': 'Clinic',
      'мектеп': 'School',
      'школа': 'School',
      'әкімдік': 'Akimat',
      'акимат': 'Akimat',
      'рынок': 'Market',
      'базар': 'Market',
    };
    for (final entry in replacements.entries) {
      result = result.replaceAll(
        RegExp(RegExp.escape(entry.key), caseSensitive: false),
        entry.value,
      );
    }
    return result;
  }

  static String _transliterate(String value) {
    const multi = <String, String>{
      'Ё': 'Yo',
      'Ж': 'Zh',
      'Х': 'Kh',
      'Ц': 'Ts',
      'Ч': 'Ch',
      'Ш': 'Sh',
      'Щ': 'Shch',
      'Ю': 'Yu',
      'Я': 'Ya',
      'Ғ': 'Gh',
      'Ң': 'Ng',
      'ё': 'yo',
      'ж': 'zh',
      'х': 'kh',
      'ц': 'ts',
      'ч': 'ch',
      'ш': 'sh',
      'щ': 'shch',
      'ю': 'yu',
      'я': 'ya',
      'ғ': 'gh',
      'ң': 'ng',
    };
    const single = <String, String>{
      'А': 'A',
      'Б': 'B',
      'В': 'V',
      'Г': 'G',
      'Д': 'D',
      'Е': 'E',
      'З': 'Z',
      'И': 'I',
      'Й': 'Y',
      'К': 'K',
      'Л': 'L',
      'М': 'M',
      'Н': 'N',
      'О': 'O',
      'П': 'P',
      'Р': 'R',
      'С': 'S',
      'Т': 'T',
      'У': 'U',
      'Ф': 'F',
      'Ъ': '',
      'Ы': 'Y',
      'Ь': '',
      'Э': 'E',
      'Қ': 'Q',
      'Ө': 'O',
      'Ұ': 'U',
      'Ү': 'U',
      'Ә': 'A',
      'І': 'I',
      'Һ': 'H',
      'а': 'a',
      'б': 'b',
      'в': 'v',
      'г': 'g',
      'д': 'd',
      'е': 'e',
      'з': 'z',
      'и': 'i',
      'й': 'y',
      'к': 'k',
      'л': 'l',
      'м': 'm',
      'н': 'n',
      'о': 'o',
      'п': 'p',
      'р': 'r',
      'с': 's',
      'т': 't',
      'у': 'u',
      'ф': 'f',
      'ъ': '',
      'ы': 'y',
      'ь': '',
      'э': 'e',
      'қ': 'q',
      'ө': 'o',
      'ұ': 'u',
      'ү': 'u',
      'ә': 'a',
      'і': 'i',
      'һ': 'h',
    };
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      buffer.write(multi[character] ?? single[character] ?? character);
    }
    return buffer.toString();
  }
}
