class StoreReleaseConfig {
  const StoreReleaseConfig._();

  static const privacyUrl = 'https://tulpartaxi.kz/privacy';
  static const termsUrl = 'https://tulpartaxi.kz/terms';
  static const accountDeletionUrl =
      'https://tulpartaxi.kz/account-deletion';

  static const supportEmail = String.fromEnvironment(
    'TULPAR_SUPPORT_EMAIL',
    defaultValue: 'support@tulpartaxi.kz',
  );
  static const appVersion = String.fromEnvironment(
    'TULPAR_APP_VERSION',
    defaultValue: '1.0.0 (1)',
  );

  static bool isValidSupportEmail(String value) => RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  ).hasMatch(value.trim());

  static bool get hasSupportEmail => isValidSupportEmail(supportEmail);
}
