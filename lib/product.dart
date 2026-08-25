// lib/models/product.dart

enum ProductCategory { grocery, dairy, toiletries, beverages, snacks, frozen, other }

extension ProductCategoryX on ProductCategory {
  String get label {
    const names = {
      ProductCategory.grocery   : 'Grocery',
      ProductCategory.dairy     : 'Dairy & Milk',
      ProductCategory.toiletries: 'Toiletries',
      ProductCategory.beverages : 'Beverages',
      ProductCategory.snacks    : 'Snacks',
      ProductCategory.frozen    : 'Frozen',
      ProductCategory.other     : 'Other',
    };
    return names[this]!;
  }

  String get emoji {
    const emojis = {
      ProductCategory.grocery   : '🛒',
      ProductCategory.dairy     : '🥛',
      ProductCategory.toiletries: '🧴',
      ProductCategory.beverages : '🥤',
      ProductCategory.snacks    : '🍪',
      ProductCategory.frozen    : '🧊',
      ProductCategory.other     : '📦',
    };
    return emojis[this]!;
  }

  static ProductCategory fromString(String v) =>
      ProductCategory.values.firstWhere((e) => e.name == v,
          orElse: () => ProductCategory.other);
}

class Product {
  final int id;
  final int userId;
  String name;
  String sku;
  ProductCategory category;
  double price;
  double costPrice;
  int quantity;
  int lowStockThreshold;
  DateTime? expiryDate;
  String? brand;
  String unit;
  // Pre-computed flags from server
  bool isExpired;
  bool isExpiringSoon;
  bool isLowStock;
  bool isOutOfStock;
  int? daysUntilExpiry;
  double profitMargin;
  DateTime? createdAt;
  DateTime? updatedAt;

  Product({
    required this.id,
    required this.userId,
    required this.name,
    required this.sku,
    required this.category,
    required this.price,
    required this.costPrice,
    required this.quantity,
    this.lowStockThreshold = 10,
    this.expiryDate,
    this.brand,
    this.unit = 'piece',
    this.isExpired = false,
    this.isExpiringSoon = false,
    this.isLowStock = false,
    this.isOutOfStock = false,
    this.daysUntilExpiry,
    this.profitMargin = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id                : j['id'] as int,
    userId            : j['user_id'] as int,
    name              : j['name'],
    sku               : j['sku'],
    category          : ProductCategoryX.fromString(j['category'] ?? 'other'),
    price             : (j['price'] as num).toDouble(),
    costPrice         : (j['cost_price'] as num).toDouble(),
    quantity          : j['quantity'] as int,
    lowStockThreshold : j['low_stock_threshold'] ?? 10,
    expiryDate        : j['expiry_date'] != null ? DateTime.tryParse(j['expiry_date']) : null,
    brand             : j['brand'],
    unit              : j['unit'] ?? 'piece',
    isExpired         : j['is_expired'] ?? false,
    isExpiringSoon    : j['is_expiring_soon'] ?? false,
    isLowStock        : j['is_low_stock'] ?? false,
    isOutOfStock      : j['is_out_of_stock'] ?? false,
    daysUntilExpiry   : j['days_until_expiry'],
    profitMargin      : (j['profit_margin'] as num?)?.toDouble() ?? 0,
    createdAt         : j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
    updatedAt         : j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
  );

  Map<String, dynamic> toJson() => {
    'user_id'             : userId,
    'name'                : name,
    'sku'                 : sku,
    'category'            : category.name,
    'price'               : price,
    'cost_price'          : costPrice,
    'quantity'            : quantity,
    'low_stock_threshold' : lowStockThreshold,
    'expiry_date'         : expiryDate?.toIso8601String().split('T').first,
    'brand'               : brand,
    'unit'                : unit,
  };

  Product copyWith({
    String? name, String? sku, ProductCategory? category,
    double? price, double? costPrice, int? quantity,
    int? lowStockThreshold, DateTime? expiryDate,
    String? brand, String? unit,
  }) => Product(
    id: id, userId: userId,
    name              : name              ?? this.name,
    sku               : sku               ?? this.sku,
    category          : category          ?? this.category,
    price             : price             ?? this.price,
    costPrice         : costPrice         ?? this.costPrice,
    quantity          : quantity          ?? this.quantity,
    lowStockThreshold : lowStockThreshold ?? this.lowStockThreshold,
    expiryDate        : expiryDate        ?? this.expiryDate,
    brand             : brand             ?? this.brand,
    unit              : unit              ?? this.unit,
    createdAt         : createdAt,
    updatedAt         : DateTime.now(),
  );
}


// lib/models/sale.dart

class Sale {
  final int id;
  final int userId;
  final int productId;
  final String productName;
  final int quantitySold;
  final double salePrice;
  final double totalAmount;
  final DateTime saleDate;
  final String? note;

  Sale({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.salePrice,
    required this.totalAmount,
    required this.saleDate,
    this.note,
  });

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
    id           : j['id'] as int,
    userId       : j['user_id'] as int,
    productId    : j['product_id'] as int,
    productName  : j['product_name'],
    quantitySold : j['quantity_sold'] as int,
    salePrice    : (j['sale_price'] as num).toDouble(),
    totalAmount  : (j['total_amount'] as num).toDouble(),
    saleDate     : DateTime.parse(j['sale_date']),
    note         : j['note'],
  );
}
