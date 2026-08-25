// lib/screens/products/products_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'product.dart';
import 'providers.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  String           _query     = '';
  ProductCategory? _filterCat;
  List<Product>    _searched  = [];
  bool             _searching = false;

  Future<void> _onSearch(String q, int userId) async {
    setState(() { _query = q; _searching = q.isNotEmpty; });
    if (q.isEmpty) { setState(() { _searched = []; _searching = false; }); return; }
    final results = await context.read<ProductProvider>().search(userId, q);
    setState(() { _searched = results; _searching = false; });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().userId;
      if (userId > 0) context.read<ProductProvider>().load(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final productP = context.watch<ProductProvider>();
    final userId   = context.watch<AuthProvider>().userId;

    List<Product> items = _query.isNotEmpty ? _searched : productP.products;
    if (_filterCat != null && _query.isEmpty) {
      items = items.where((p) => p.category == _filterCat).toList();
    }

    return Scaffold(
      appBar: AppBar(
          title: const Text('Products'),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh_outlined, color: Colors.white),
                onPressed: () => productP.load(userId))
          ]),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 100% Full-width search bar banner
            Container(
                width: double.infinity,
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => _onSearch(v, userId),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      hintText: 'Search products, SKU, brand...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
                      prefixIcon: _searching
                          ? const Padding(padding: EdgeInsets.all(12),
                          child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)))
                          : const Icon(Icons.search, color: Colors.white70),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearch('', userId);
                          }) : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white30)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                )),

            // 100% Full-width Category filter chips
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    _FilterChip(label: 'All', selected: _filterCat == null,
                        onTap: () => setState(() => _filterCat = null)),
                    ...ProductCategory.values.map((c) => _FilterChip(
                        label: '${c.emoji} ${c.label}',
                        selected: _filterCat == c,
                        color: AppColors.categoryColors[c.name],
                        onTap: () => setState(() => _filterCat = _filterCat == c ? null : c))),
                  ])),
            ),

            Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(children: [
                  Text('${items.length} products',
                      style: const TextStyle(color: AppColors.textSecondary,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ])),

            // 100% Full-width responsive product grid/list
            Expanded(
                child: productP.loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : items.isEmpty
                    ? _EmptyState(hasQuery: _query.isNotEmpty)
                    : RefreshIndicator(
                    onRefresh: () => productP.load(userId),
                    color: AppColors.primary,
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final width = constraints.maxWidth;
                        // Dynamically scale columns to fill 100% of available screen width
                        final int crossAxisCount = (width / 340).clamp(1, 4).toInt();
                        
                        if (crossAxisCount > 1) {
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            itemCount: items.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: (width / crossAxisCount) > 420 ? 3.6 : 3.0,
                            ),
                            itemBuilder: (ctx, i) => _ProductCard(product: items[i]),
                          );
                        }
                        return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) => _ProductCard(product: items[i]));
                      },
                    ))),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected,
    required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
                color: selected ? c : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? c : AppColors.divider)),
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.textSecondary))));
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

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
              border: product.isExpired
                  ? Border.all(color: AppColors.danger.withOpacity(0.4), width: 1.5)
                  : product.isLowStock
                  ? Border.all(color: AppColors.warning.withOpacity(0.4), width: 1.5)
                  : Border.all(color: AppColors.divider.withOpacity(0.4)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
                  blurRadius: 4, offset: const Offset(0, 1))]),
          child: Row(children: [
            Container(width: 48, height: 48,
                decoration: BoxDecoration(color: catColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(product.category.emoji,
                    style: const TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [
                Expanded(child: Text(product.name, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                if (product.isExpired)       _Badge('EXPIRED', AppColors.danger)
                else if (product.isExpiringSoon) _Badge('EXP SOON', AppColors.warning)
                else if (product.isOutOfStock)   _Badge('OUT', AppColors.danger)
                else if (product.isLowStock)     _Badge('LOW', AppColors.warning),
              ]),
              const SizedBox(height: 2),
              Text('${product.brand != null && product.brand!.isNotEmpty ? "${product.brand} • " : ""}SKU: ${product.sku}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 5),
              Row(children: [
                _InfoPill('₹${product.price.toStringAsFixed(0)}', AppColors.success),
                const SizedBox(width: 6),
                _InfoPill('Qty: ${product.quantity}',
                    product.isLowStock ? AppColors.warning : AppColors.primary),
              ]),
            ])),
            const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
          ]),
        ));
  }
}

class _Badge extends StatelessWidget {
  final String label; final Color color;
  const _Badge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(fontSize: 9,
          fontWeight: FontWeight.w700, color: color)));
}

class _InfoPill extends StatelessWidget {
  final String text; final Color color;
  const _InfoPill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w600, color: color)));
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});
  @override
  Widget build(BuildContext context) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(hasQuery ? '🔍' : '📦', style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(hasQuery ? 'No products found' : 'No products yet',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(hasQuery ? 'Try a different search' : 'Tap + to add your first product',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ]));
}