class TulparApiConfig {
  const TulparApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'TULPAR_API_BASE_URL',
    defaultValue: 'https://api.tulpartaxi.kz',
  );
}
