// lib/screens/alerts/alerts_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'product.dart';
import 'providers.dart';
import 'product_detail_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProductProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Expired (${pp.expired.length})'),
            Tab(text: 'Expiring (${pp.expiringSoon.length})'),
            Tab(text: 'Low Stock (${pp.lowStock.length})'),
          ])),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: TabBarView(controller: _tabs, children: [
          _AlertList(products: pp.expired,      type: AlertType.expired,
              emptyMsg: 'No expired products 🎉',
              emptyDesc: 'All products are within their expiry dates.'),
          _AlertList(products: pp.expiringSoon, type: AlertType.expiringSoon,
              emptyMsg: 'Nothing expiring soon 🎉',
              emptyDesc: 'No products expiring in the next 7 days.'),
          _AlertList(products: pp.lowStock,     type: AlertType.lowStock,
              emptyMsg: 'Stock looks good! 🎉',
              emptyDesc: 'All products are above the low stock threshold.'),
        ]),
      ),
    );
  }
}

enum AlertType { expired, expiringSoon, lowStock }

class _AlertList extends StatelessWidget {
  final List<Product> products;
  final AlertType type;
  final String emptyMsg, emptyDesc;
  const _AlertList({required this.products, required this.type,
      required this.emptyMsg, required this.emptyDesc});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(emptyMsg, style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(emptyDesc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
        ])));
    }
    return RefreshIndicator(
      onRefresh: () {
        final uid = context.read<AuthProvider>().userId;
        return context.read<ProductProvider>().load(uid);
      },
      color: AppColors.primary,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final width = constraints.maxWidth;
          final int crossAxisCount = (width / 360).clamp(1, 4).toInt();
          
          if (crossAxisCount > 1) {
            return GridView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: (width / crossAxisCount) > 420 ? 3.6 : 3.0,
              ),
              itemBuilder: (ctx, i) => _AlertCard(product: products[i], type: type),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _AlertCard(product: products[i], type: type));
        },
      ));
  }
}

class _AlertCard extends StatelessWidget {
  final Product product;
  final AlertType type;
  const _AlertCard({required this.product, required this.type});

  Color get _color {
    switch (type) {
      case AlertType.expired:      return AppColors.danger;
      case AlertType.expiringSoon: return AppColors.warning;
      case AlertType.lowStock:     return const Color(0xFF1565C0);
    }
  }

  IconData get _icon {
    switch (type) {
      case AlertType.expired:      return Icons.dangerous_outlined;
      case AlertType.expiringSoon: return Icons.hourglass_bottom_outlined;
      case AlertType.lowStock:     return Icons.inventory_outlined;
    }
  }

  String get _subtitle {
    switch (type) {
      case AlertType.expired:
        final days = product.daysUntilExpiry;
        return 'Expired ${days != null ? -days : "?"} day(s) ago';
      case AlertType.expiringSoon:
        final days = product.daysUntilExpiry ?? 0;
        if (days == 0) return 'Expires TODAY';
        if (days == 1) return 'Expires TOMORROW';
        return 'Expires in $days days — ${product.expiryDate != null ? DateFormat("d MMM").format(product.expiryDate!) : ""}';
      case AlertType.lowStock:
        return 'Only ${product.quantity} left (threshold: ${product.lowStockThreshold})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppColors.categoryColors[product.category.name] ?? AppColors.primary;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _color.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: _color.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: _color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(_icon, color: _color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text('${product.brand != null && product.brand!.isNotEmpty ? "${product.brand} • " : ""}${product.category.label}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5)),
              child: Text(_subtitle,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _color))),
          ])),
          Container(width: 34, height: 34,
            decoration: BoxDecoration(color: catColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(product.category.emoji,
                style: const TextStyle(fontSize: 18)))),
        ])));
  }
}
