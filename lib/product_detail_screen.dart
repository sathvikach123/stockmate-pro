// lib/screens/products/product_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'product.dart';
import 'providers.dart';
import 'add_product_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product _product;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  Future<void> _updateQty() async {
    final ctrl = TextEditingController(text: _product.quantity.toString());
    final result = await showModalBottomSheet<int>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _UpdateQtySheet(product: _product, ctrl: ctrl));

    if (result != null && mounted) {
      final userId = context.read<AuthProvider>().userId;
      final error  = await context.read<ProductProvider>().updateQty(
          userId, _product.id, result);
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error), backgroundColor: AppColors.danger));
      } else {
        setState(() => _product = _product.copyWith(quantity: result));
      }
    }
  }

  Future<void> _recordSale() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _RecordSaleSheet(product: _product));

    if (result != null && mounted) {
      final userId = context.read<AuthProvider>().userId;
      final error  = await context.read<SalesProvider>().recordSale(userId, {
        'product_id'   : _product.id,
        'quantity_sold': result['qty'],
        'sale_price'   : result['price'],
        'note'         : result['note'],
      });
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error), backgroundColor: AppColors.danger));
      } else {
        final newQty = _product.quantity - (result['qty'] as int);
        setState(() => _product = _product.copyWith(quantity: newQty));
        // Refresh dashboard + products
        context.read<ProductProvider>().load(userId);
        context.read<DashboardProvider>().load(userId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sale recorded!'), backgroundColor: AppColors.success));
      }
    }
  }

  void _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${_product.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ]));
    if (confirm == true && mounted) {
      final userId = context.read<AuthProvider>().userId;
      final error  = await context.read<ProductProvider>().delete(userId, _product.id);
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error), backgroundColor: AppColors.danger));
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppColors.categoryColors[_product.category.name] ?? AppColors.primary;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 220, pinned: true,
          backgroundColor: catColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddProductScreen(product: _product)));
                if (mounted) {
                  final uid     = context.read<AuthProvider>().userId;
                  await context.read<ProductProvider>().load(uid);
                  final updated = context.read<ProductProvider>()
                      .products.firstWhere((p) => p.id == _product.id,
                      orElse: () => _product);
                  setState(() => _product = updated);
                }
              }),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: _delete),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(gradient: LinearGradient(
                  colors: [catColor.withOpacity(0.8), catColor],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(height: 60),
                Text(_product.category.emoji, style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 8),
                Text(_product.category.label,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]))),
        ),

        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider.withOpacity(0.4)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
                          blurRadius: 4, offset: const Offset(0, 1))]),
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(_product.name,
                            style: Theme.of(context).textTheme.headlineLarge)),
                        if (_product.isExpired)        _StatusBadge('EXPIRED', AppColors.danger)
                        else if (_product.isExpiringSoon) _StatusBadge('EXPIRING SOON', AppColors.warning)
                        else if (_product.isOutOfStock)   _StatusBadge('OUT OF STOCK', AppColors.danger)
                        else if (_product.isLowStock)     _StatusBadge('LOW STOCK', AppColors.warning),
                      ]),
                      const SizedBox(height: 4),
                      Text('${_product.brand ?? ''} • SKU: ${_product.sku}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 16),
                      Row(children: [
                        _MetricCard('Selling Price', currency.format(_product.price), AppColors.success),
                        const SizedBox(width: 10),
                        _MetricCard('Cost Price', currency.format(_product.costPrice),
                            const Color(0xFF1565C0)),
                        const SizedBox(width: 10),
                        _MetricCard('Margin', '${_product.profitMargin.toStringAsFixed(1)}%',
                            AppColors.primary),
                      ]),
                    ])),

                  const SizedBox(height: 12),

                  // Stock info
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider.withOpacity(0.4)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
                          blurRadius: 4, offset: const Offset(0, 1))]),
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Stock Information', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      _InfoRow('Current Quantity', '${_product.quantity} ${_product.unit}',
                          icon: Icons.inventory_2_outlined,
                          valueColor: _product.isLowStock ? AppColors.warning : AppColors.textPrimary),
                      _InfoRow('Low Stock Alert', '${_product.lowStockThreshold} ${_product.unit}',
                          icon: Icons.warning_amber_outlined, valueColor: AppColors.warning),
                      _InfoRow('Unit', _product.unit, icon: Icons.straighten_outlined),
                      if (_product.expiryDate != null)
                        _InfoRow('Expiry Date',
                          '${DateFormat('d MMMM yyyy').format(_product.expiryDate!)} '
                          '(${_product.daysUntilExpiry != null && _product.daysUntilExpiry! >= 0
                              ? "${_product.daysUntilExpiry} days left"
                              : "Expired"})',
                          icon: Icons.event_outlined,
                          valueColor: _product.isExpired ? AppColors.danger
                              : _product.isExpiringSoon ? AppColors.warning
                              : AppColors.textPrimary),
                      if (_product.createdAt != null)
                        _InfoRow('Added', DateFormat('d MMM yyyy').format(_product.createdAt!),
                            icon: Icons.add_circle_outline),
                      if (_product.updatedAt != null)
                        _InfoRow('Last Updated', DateFormat('d MMM yyyy').format(_product.updatedAt!),
                            icon: Icons.update),
                    ])),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: _updateQty,
                        icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                        label: const Text('Update Qty',
                            style: TextStyle(color: AppColors.primary)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton.icon(
                        onPressed: _recordSale,
                        icon: const Icon(Icons.point_of_sale_outlined, size: 18),
                        label: const Text('Record Sale'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)))),
                    ])),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label; final Color color;
  const _StatusBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)));
}

class _MetricCard extends StatelessWidget {
  final String label, value; final Color color;
  const _MetricCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          textAlign: TextAlign.center),
    ])));
}

class _InfoRow extends StatelessWidget {
  final String label, value; final IconData icon; final Color? valueColor;
  const _InfoRow(this.label, this.value, {required this.icon, this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: 10),
      Expanded(child: Text(label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
          color: valueColor ?? AppColors.textPrimary)),
    ]));
}

// ── Update Quantity Sheet ─────────────────────────────────────────────────────
class _UpdateQtySheet extends StatelessWidget {
  final Product product;
  final TextEditingController ctrl;
  const _UpdateQtySheet({required this.product, required this.ctrl});

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.divider,
              borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 20),
      Text('Update Quantity', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text('${product.name} • Current: ${product.quantity}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 20),
      TextFormField(
        controller: ctrl, autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'New Quantity',
            prefixIcon: Icon(Icons.inventory_outlined, color: AppColors.primary))),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.divider),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: () {
            final v = int.tryParse(ctrl.text);
            if (v != null) Navigator.pop(context, v);
          },
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Update'))),
      ]),
    ]));
}

// ── Record Sale Sheet ─────────────────────────────────────────────────────────
class _RecordSaleSheet extends StatefulWidget {
  final Product product;
  const _RecordSaleSheet({required this.product});
  @override
  State<_RecordSaleSheet> createState() => __RecordSaleSheetState();
}

class __RecordSaleSheetState extends State<_RecordSaleSheet> {
  final _qtyCtrl  = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  late TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.product.price.toString());
  }

  double get total {
    final q = int.tryParse(_qtyCtrl.text) ?? 0;
    final p = double.tryParse(_priceCtrl.text) ?? 0;
    return q * p;
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.divider,
              borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 20),
      Text('Record Sale', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text('${widget.product.name} • Stock: ${widget.product.quantity}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: TextFormField(
          controller: _qtyCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Quantity Sold',
              prefixIcon: Icon(Icons.shopping_bag_outlined, color: AppColors.primary)))),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Price (₹)',
              prefixIcon: Icon(Icons.currency_rupee, color: AppColors.primary)))),
      ]),
      const SizedBox(height: 12),
      TextFormField(
        controller: _noteCtrl,
        decoration: const InputDecoration(labelText: 'Note (optional)',
            prefixIcon: Icon(Icons.note_outlined, color: AppColors.primary))),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total Amount',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('₹${total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800,
                  color: AppColors.success, fontSize: 18)),
        ])),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.divider),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: () {
            final q = int.tryParse(_qtyCtrl.text);
            final p = double.tryParse(_priceCtrl.text);
            if (q == null || q <= 0) return;
            if (q > widget.product.quantity) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Not enough stock!'),
                  backgroundColor: AppColors.danger));
              return;
            }
            Navigator.pop(context, {
              'qty'  : q,
              'price': p ?? widget.product.price,
              'note' : _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            });
          },
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Confirm Sale'))),
      ]),
    ]));
}
