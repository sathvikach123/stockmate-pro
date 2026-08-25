// lib/screens/products/add_product_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'product.dart';
import 'providers.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;
  const AddProductScreen({super.key, this.product});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _form       = GlobalKey<FormState>();
  late TextEditingController _name, _sku, _brand, _price, _cost, _qty, _threshold;
  late ProductCategory _category;
  late String _unit;
  DateTime? _expiryDate;
  bool _loading = false;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p   = widget.product;
    _name      = TextEditingController(text: p?.name       ?? '');
    _sku       = TextEditingController(text: p?.sku        ?? '');
    _brand     = TextEditingController(text: p?.brand      ?? '');
    _price     = TextEditingController(text: p?.price.toString()     ?? '');
    _cost      = TextEditingController(text: p?.costPrice.toString() ?? '');
    _qty       = TextEditingController(text: p?.quantity.toString()  ?? '0');
    _threshold = TextEditingController(text: p?.lowStockThreshold.toString() ?? '10');
    _category  = p?.category ?? ProductCategory.grocery;
    _unit      = p?.unit ?? 'piece';
    _expiryDate= p?.expiryDate;
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _brand, _price, _cost, _qty, _threshold]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    final userId   = context.read<AuthProvider>().userId;
    final provider = context.read<ProductProvider>();

    final data = {
      'user_id'             : userId,
      'name'                : _name.text.trim(),
      'sku'                 : _sku.text.trim(),
      'brand'               : _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      'category'            : _category.name,
      'price'               : double.parse(_price.text),
      'cost_price'          : double.parse(_cost.text),
      'quantity'            : int.parse(_qty.text),
      'low_stock_threshold' : int.parse(_threshold.text),
      'expiry_date'         : _expiryDate?.toIso8601String().split('T').first,
      'unit'                : _unit,
    };

    final error = isEdit
        ? await provider.update(userId, widget.product!.id, data)
        : await provider.add(userId, data);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error), backgroundColor: AppColors.danger));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEdit ? 'Product updated!' : 'Product added!'),
        backgroundColor: AppColors.success));
    Navigator.pop(context, true); // true = data changed, caller must reload
  }

  Future<void> _pickExpiry() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
        builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(primary: AppColors.primary)),
            child: child!));
    if (d != null) setState(() => _expiryDate = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(isEdit ? 'Edit Product' : 'Add Product'),
          actions: [
            TextButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('SAVE', style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700))),
          ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _form,
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SectionHeader('Basic Information'),
                  const SizedBox(height: 12),

                  TextFormField(controller: _name,
                      decoration: const InputDecoration(labelText: 'Product Name *',
                          prefixIcon: Icon(Icons.label_outline, color: AppColors.primary)),
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 14),

                  Row(children: [
                    Expanded(child: TextFormField(controller: _sku,
                        decoration: const InputDecoration(labelText: 'SKU *',
                            prefixIcon: Icon(Icons.qr_code, color: AppColors.primary)),
                        validator: (v) => v!.isEmpty ? 'Required' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _brand,
                        decoration: const InputDecoration(labelText: 'Brand',
                            prefixIcon: Icon(Icons.branding_watermark_outlined,
                                color: AppColors.primary)))),
                  ]),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<ProductCategory>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Category *',
                          prefixIcon: Icon(Icons.category_outlined, color: AppColors.primary)),
                      items: ProductCategory.values.map((c) => DropdownMenuItem(
                          value: c, child: Text('${c.emoji} ${c.label}'))).toList(),
                      onChanged: (v) => setState(() => _category = v!)),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Unit',
                          prefixIcon: Icon(Icons.straighten_outlined, color: AppColors.primary)),
                      items: ['piece', 'kg', 'g', 'litre', 'ml', 'pack', 'box', 'dozen']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _unit = v!)),

                  const SizedBox(height: 24),
                  _SectionHeader('Pricing'),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: TextFormField(controller: _price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: const InputDecoration(labelText: 'Selling Price (₹) *',
                            prefixIcon: Icon(Icons.currency_rupee, color: AppColors.primary)),
                        validator: (v) => v!.isEmpty ? 'Required' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _cost,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: const InputDecoration(labelText: 'Cost Price (₹) *',
                            prefixIcon: Icon(Icons.currency_rupee, color: AppColors.primary)),
                        validator: (v) => v!.isEmpty ? 'Required' : null)),
                  ]),

                  const SizedBox(height: 24),
                  _SectionHeader('Stock'),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: TextFormField(controller: _qty,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Current Quantity *',
                            prefixIcon: Icon(Icons.inventory_outlined, color: AppColors.primary)),
                        validator: (v) => v!.isEmpty ? 'Required' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _threshold,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Low Stock Alert At',
                            prefixIcon: Icon(Icons.warning_amber_outlined,
                                color: AppColors.warning)))),
                  ]),

                  const SizedBox(height: 24),
                  _SectionHeader('Expiry Date'),
                  const SizedBox(height: 12),

                  GestureDetector(
                      onTap: _pickExpiry,
                      child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider, width: 1.5)),
                          child: Row(children: [
                            const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(child: Text(
                                _expiryDate == null
                                    ? 'Set expiry date (optional)'
                                    : DateFormat('d MMMM yyyy').format(_expiryDate!),
                                style: TextStyle(
                                    color: _expiryDate == null ? AppColors.textHint : AppColors.textPrimary,
                                    fontSize: 14))),
                            if (_expiryDate != null)
                              GestureDetector(
                                  onTap: () => setState(() => _expiryDate = null),
                                  child: const Icon(Icons.close, color: AppColors.textSecondary, size: 18)),
                          ]))),

                  const SizedBox(height: 32),
                  SizedBox(width: double.infinity, height: 50,
                      child: ElevatedButton(
                          onPressed: _loading ? null : _save,
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                              : Text(isEdit ? 'Update Product' : 'Add Product'))),
                  const SizedBox(height: 40),
                ])),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.primary, letterSpacing: 0.5));
}