class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'https://shadja.my.id';
  static const String apiPrefix = '/api/v1';

  static String _path(String endpoint) => endpoint;

  // Auth
  static String get register => _path('/auth/register');
  static String get login => _path('/auth/login');
  static String get logout => _path('/auth/logout');

  // Menu
  static String get menu => _path('/menu');
  static String menuItem(int id) => _path('/menu/$id');

  // Orders
  static String get orders => _path('/orders');
  static String order(int id) => _path('/orders/$id');
  static String orderStatus(int id) => _path('/orders/$id/status');

  // Additional costs (biaya tambahan, mis. service charge)
  static String get additionalCosts => _path('/additional-costs');

  // Payments
  static String get paymentCallback => _path('/payments/callback');
  static String payment(int id) => _path('/payments/$id');

  // Profile
  static String get profile => _path('/profile');

  // Reservations
  static String get reservations => _path('/reservations');
  static String reservation(int id) => _path('/reservations/$id');

  // Tables
  static String get tables => _path('/tables');
  static String table(int id) => _path('/tables/$id');

  // Sync
  static String get sync => _path('/sync');
}