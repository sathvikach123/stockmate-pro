// lib/api_urls.dart
// Single source of truth for all API endpoints.

class ApiUrl {
  // Configured for local Wi-Fi / physical devices & web
  static const String base = 'http://172.20.10.6:8000';

  // Auth
  static const String signup      = '$base/signup';
  static const String login       = '$base/login';
  static const String logout      = '$base/logout';
  static const String currentUser = '$base/get_current_user';

  // Products
  static String products(int userId)                        => '$base/products/$userId';
  static String productsByCategory(int userId, String cat)  => '$base/products/$userId?category=$cat';
  static String searchProducts(int userId, String q)        => '$base/products/search/$userId?q=$q';
  static String alerts(int userId)                          => '$base/products/alerts/$userId';
  static String addProduct()                                => '$base/products';
  static String updateProduct(int id)                       => '$base/products/$id';
  static String updateQuantity(int id)                      => '$base/products/$id/quantity';
  static String deleteProduct(int id)                       => '$base/products/$id';

  // Sales
  static String sales(int userId)  => '$base/sales/$userId';
  static String recordSale()       => '$base/sales';
  static String deleteSale(int id) => '$base/sales/$id';

  // Dashboard and Analytics
  static String dashboard(int userId) => '$base/dashboard/$userId';
  static String analytics(int userId) => '$base/analytics/$userId';
}