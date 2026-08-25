// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stockmate_pro/product.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool   _isLoggedIn = false;
  int    _userId     = 0;
  String _userName   = '';
  String _userEmail  = '';
  String _storeName  = 'My Store';

  bool   get isLoggedIn => _isLoggedIn;
  int    get userId     => _userId;
  String get userName   => _userName;
  String get userEmail  => _userEmail;
  String get storeName  => _storeName;

  Future<void> init() async {
    // Always start fresh — user must log in every time
    _isLoggedIn = false;
    _userId     = 0;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    final res = await ApiService.login(email: email, password: password);
    if (!res['success']) return res['error'] ?? 'Login failed';
    final user = res['data']['user'];
    await _saveSession(user);
    return null; // null = success
  }

  Future<String?> signup(String name, String email, String password, String store) async {
    final res = await ApiService.signup(
        name: name, email: email, password: password, storeName: store);
    if (!res['success']) return res['error'] ?? 'Signup failed';
    // Auto-login after signup
    return login(email, password);
  }

  Future<void> logout() async {
    await ApiService.logout(_userEmail);
    _isLoggedIn = false;
    _userId     = 0;
    _userName   = '';
    _userEmail  = '';
    _storeName  = 'My Store';
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  Future<void> _saveSession(Map<String, dynamic> user) async {
    _isLoggedIn = true;
    _userId     = user['id'] as int;
    _userName   = user['name'];
    _userEmail  = user['email'];
    _storeName  = user['store_name'] ?? 'My Store';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logged_in',    true);
    await prefs.setInt('user_id',       _userId);
    await prefs.setString('user_name',  _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('store_name', _storeName);
    notifyListeners();
  }
}


// lib/providers/product_provider.dart


class ProductProvider extends ChangeNotifier {
  List<Product> _products     = [];
  List<Product> _lowStock     = [];
  List<Product> _expired      = [];
  List<Product> _expiringSoon = [];
  bool   _loading = false;
  String _error   = '';

  List<Product> get products     => _products;
  List<Product> get lowStock     => _lowStock;
  List<Product> get expired      => _expired;
  List<Product> get expiringSoon => _expiringSoon;
  bool          get loading      => _loading;
  String        get error        => _error;

  int    get totalProducts   => _products.length;
  int    get alertCount      => _lowStock.length + _expired.length + _expiringSoon.length;
  double get totalStockValue =>
      _products.fold(0, (sum, p) => sum + p.costPrice * p.quantity);

  Future<void> load(int userId) async {
    _loading = true;
    _error   = '';
    notifyListeners();
    try {
      // Load products + alerts in parallel
      final results = await Future.wait([
        ApiService.getProducts(userId),
        ApiService.getAlerts(userId),
      ]);

      final prodRes  = results[0];
      final alertRes = results[1];

      if (prodRes['success']) {
        _products = (prodRes['data'] as List)
            .map((j) => Product.fromJson(j))
            .toList();
      }
      if (alertRes['success']) {
        final d    = alertRes['data'];
        _lowStock     = (d['low_stock']     as List).map((j) => Product.fromJson(j)).toList();
        _expired      = (d['expired']       as List).map((j) => Product.fromJson(j)).toList();
        _expiringSoon = (d['expiring_soon'] as List).map((j) => Product.fromJson(j)).toList();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('ProductProvider.load error: $_error');
    }
    _loading = false;
    notifyListeners();
  }

  Future<List<Product>> search(int userId, String q) async {
    final res = await ApiService.searchProducts(userId, q);
    if (!res['success']) return [];
    return (res['data'] as List).map((j) => Product.fromJson(j)).toList();
  }

  Future<String?> add(int userId, Map<String, dynamic> data) async {
    final res = await ApiService.addProduct({...data, 'user_id': userId});
    if (!res['success']) return res['error'];
    await load(userId);
    return null;
  }

  Future<String?> update(int userId, int productId, Map<String, dynamic> data) async {
    final res = await ApiService.updateProduct(productId, data);
    if (!res['success']) return res['error'];
    await load(userId);
    return null;
  }

  Future<String?> updateQty(int userId, int productId, int qty) async {
    final res = await ApiService.updateQuantity(productId, qty);
    if (!res['success']) return res['error'];
    await load(userId);
    return null;
  }

  Future<String?> delete(int userId, int productId) async {
    final res = await ApiService.deleteProduct(productId);
    if (!res['success']) return res['error'];
    await load(userId);
    return null;
  }
}


// lib/providers/sales_provider.dart


class SalesProvider extends ChangeNotifier {
  List<Sale>               _sales      = [];
  List<Map<String, dynamic>> _chartData  = [];
  List<Map<String, dynamic>> _topProducts= [];
  double _todayRevenue = 0;
  double _weekRevenue  = 0;
  double _totalRevenue = 0;
  int    _totalTxns    = 0;
  bool   _loading      = false;

  List<Sale>                 get sales        => _sales;
  List<Map<String, dynamic>> get chartData    => _chartData;
  List<Map<String, dynamic>> get topProducts  => _topProducts;
  double get todayRevenue  => _todayRevenue;
  double get weekRevenue   => _weekRevenue;
  double get totalRevenue  => _totalRevenue;
  int    get totalTxns     => _totalTxns;
  bool   get loading       => _loading;

  Future<void> load(int userId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getAnalytics(userId);
      if (res['success']) {
        final d    = res['data'];
        _sales       = (d['sales'] as List).map((j) => Sale.fromJson(j)).toList();
        _chartData   = List<Map<String, dynamic>>.from(d['chart_data'] ?? []);
        _topProducts = List<Map<String, dynamic>>.from(d['top_products'] ?? []);
        _todayRevenue = (d['today_revenue'] as num?)?.toDouble() ?? 0;
        _weekRevenue  = (d['week_revenue']  as num?)?.toDouble() ?? 0;
        _totalRevenue = (d['total_revenue'] as num?)?.toDouble() ?? 0;
        _totalTxns    = (d['total_transactions'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<String?> recordSale(int userId, Map<String, dynamic> data) async {
    final res = await ApiService.recordSale({...data, 'user_id': userId});
    if (!res['success']) return res['error'];
    await load(userId);
    return null;
  }
}


// lib/providers/dashboard_provider.dart


class DashboardProvider extends ChangeNotifier {
  int    _totalProducts   = 0;
  double _totalStockValue = 0;
  double _todayRevenue    = 0;
  double _weekRevenue     = 0;
  double _totalRevenue    = 0;
  int    _totalTxns       = 0;
  Map<String, int> _alerts = {};
  List<Sale>               _recentSales  = [];
  List<Map<String, dynamic>> _chartData  = [];
  List<Map<String, dynamic>> _topProducts= [];
  Map<String, int>         _catCounts    = {};
  bool   _loading = false;

  int    get totalProducts   => _totalProducts;
  double get totalStockValue => _totalStockValue;
  double get todayRevenue    => _todayRevenue;
  double get weekRevenue     => _weekRevenue;
  double get totalRevenue    => _totalRevenue;
  int    get totalTxns       => _totalTxns;
  int    get totalAlerts     => _alerts['total'] ?? 0;
  int    get lowStockCount   => (_alerts['low_stock'] ?? 0) + (_alerts['out_of_stock'] ?? 0);
  int    get expiredCount    => _alerts['expired'] ?? 0;
  int    get expiringSoonCount => _alerts['expiring_soon'] ?? 0;
  List<Sale>                 get recentSales  => _recentSales;
  List<Map<String, dynamic>> get chartData   => _chartData;
  List<Map<String, dynamic>> get topProducts => _topProducts;
  Map<String, int>           get catCounts   => _catCounts;
  bool                       get loading     => _loading;

  Future<void> load(int userId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getDashboard(userId);
      if (res['success']) {
        final d = res['data'];
        _totalProducts   = (d['total_products']   as num?)?.toInt()    ?? 0;
        _totalStockValue = (d['total_stock_value'] as num?)?.toDouble() ?? 0;
        _todayRevenue    = (d['today_revenue']     as num?)?.toDouble() ?? 0;
        _weekRevenue     = (d['week_revenue']      as num?)?.toDouble() ?? 0;
        _totalRevenue    = (d['total_revenue']     as num?)?.toDouble() ?? 0;
        _totalTxns       = (d['total_transactions']as num?)?.toInt()    ?? 0;
        _alerts          = Map<String, int>.from(
            (d['alerts'] as Map).map((k, v) => MapEntry(k, (v as num).toInt())));
        _recentSales     = (d['recent_sales'] as List)
            .map((j) => Sale.fromJson(j)).toList();
        _chartData       = List<Map<String, dynamic>>.from(d['chart_data'] ?? []);
        _topProducts     = List<Map<String, dynamic>>.from(d['top_products'] ?? []);
        _catCounts       = Map<String, int>.from(
            (d['category_counts'] as Map? ?? {}).map((k, v) => MapEntry(k, (v as num).toInt())));
      }
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }
}