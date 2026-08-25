// lib/api_service.dart
// All HTTP calls go through this file. Swap base URL in api_urls.dart only.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_urls.dart';

class ApiService {
  static final _headers = {'Content-Type': 'application/json'};
  static const _timeout = Duration(seconds: 15);

  // Generic helpers

  static Future<Map<String, dynamic>> _get(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(_timeout);
      return _parse(res);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> _post(String url, Map body) async {
    try {
      final res = await http
          .post(Uri.parse(url), headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);
      return _parse(res);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> _put(String url, Map body) async {
    try {
      final res = await http
          .put(Uri.parse(url), headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);
      return _parse(res);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> _patch(String url, Map body) async {
    try {
      final res = await http
          .patch(Uri.parse(url), headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);
      return _parse(res);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> _delete(String url) async {
    try {
      final res = await http
          .delete(Uri.parse(url), headers: _headers)
          .timeout(_timeout);
      return _parse(res);
    } catch (e) {
      return {'success': false, 'error': 'Connection failed: $e'};
    }
  }

  static Map<String, dynamic> _parse(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': decoded, 'status': res.statusCode};
      }
      // FastAPI returns errors under 'detail', fallback to 'error' or 'message'
      final errBody = decoded is Map ? decoded : {};
      final errMsg = errBody['detail'] ??
          errBody['error'] ??
          errBody['message'] ??
          'Error ${res.statusCode}';
      return {'success': false, 'error': errMsg.toString(), 'status': res.statusCode};
    } catch (e) {
      return {'success': false, 'error': 'Parse error: $e'};
    }
  }

  // Auth

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    required String storeName,
  }) => _post(ApiUrl.signup, {
    'name': name, 'email': email,
    'password': password, 'store_name': storeName,
  });

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _post(ApiUrl.login, {'email': email, 'password': password});

  static Future<Map<String, dynamic>> logout(String email) =>
      _post(ApiUrl.logout, {'email': email});

  static Future<Map<String, dynamic>> getCurrentUser() =>
      _get(ApiUrl.currentUser);

  // Products

  static Future<Map<String, dynamic>> getProducts(int userId) =>
      _get(ApiUrl.products(userId));

  static Future<Map<String, dynamic>> searchProducts(int userId, String q) =>
      _get(ApiUrl.searchProducts(userId, q));

  static Future<Map<String, dynamic>> getAlerts(int userId) =>
      _get(ApiUrl.alerts(userId));

  static Future<Map<String, dynamic>> addProduct(Map<String, dynamic> data) =>
      _post(ApiUrl.addProduct(), data);

  static Future<Map<String, dynamic>> updateProduct(int id, Map<String, dynamic> data) =>
      _put(ApiUrl.updateProduct(id), data);

  static Future<Map<String, dynamic>> updateQuantity(int id, int qty) =>
      _patch(ApiUrl.updateQuantity(id), {'quantity': qty});

  static Future<Map<String, dynamic>> deleteProduct(int id) =>
      _delete(ApiUrl.deleteProduct(id));

  // Sales

  static Future<Map<String, dynamic>> getSales(int userId) =>
      _get(ApiUrl.sales(userId));

  static Future<Map<String, dynamic>> recordSale(Map<String, dynamic> data) =>
      _post(ApiUrl.recordSale(), data);

  static Future<Map<String, dynamic>> deleteSale(int id) =>
      _delete(ApiUrl.deleteSale(id));

  // Dashboard & Analytics

  static Future<Map<String, dynamic>> getDashboard(int userId) =>
      _get(ApiUrl.dashboard(userId));

  static Future<Map<String, dynamic>> getAnalytics(int userId) =>
      _get(ApiUrl.analytics(userId));
}