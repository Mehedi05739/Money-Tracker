class ApiEndpoints {
  const ApiEndpoints._();

  /// Swap per flavor/environment (see `lib/core/config`).
  static const String baseUrl = 'https://api.example.com';
  static const String apiVersion = '/api/v1';

  static const String login = '$apiVersion/auth/login';
  static const String refresh = '$apiVersion/auth/refresh';
  static const String profile = '$apiVersion/user/profile';

  static const String transactions = '$apiVersion/transactions';
  static String transactionById(String id) => '$transactions/$id';
}
