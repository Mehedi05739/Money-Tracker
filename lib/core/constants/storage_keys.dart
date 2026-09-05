/// Every key written to persistent storage lives here, so no two features can
/// silently collide on the same string.
class StorageKeys {
  const StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userProfile = 'user_profile';
  static const String themeMode = 'theme_mode';
  static const String languageCode = 'language_code';
  static const String cachedTransactions = 'cached_transactions';
}
