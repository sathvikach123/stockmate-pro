// lib/screens/account/account_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'providers.dart';
import 'login_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final dash  = context.watch<DashboardProvider>();
    final salesP= context.watch<SalesProvider>();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 36),
                        // Avatar
                        Container(
                            width: 68, height: 68,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 12, offset: const Offset(0, 4))]),
                            child: Center(
                                child: Text(
                                    auth.userName.isNotEmpty
                                        ? auth.userName[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary)))),
                        const SizedBox(height: 10),
                        Text(auth.userName,
                            style: const TextStyle(fontSize: 18,
                                fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(auth.userEmail,
                            style: TextStyle(fontSize: 12,
                                color: Colors.white.withOpacity(0.75))),
                      ])),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store info card
                  _InfoCard(children: [
                    _InfoRow(Icons.store_outlined, 'Store Name', auth.storeName),
                    const Divider(color: AppColors.divider, height: 1),
                    _InfoRow(Icons.email_outlined, 'Email', auth.userEmail),
                  ]),

                  const SizedBox(height: 20),
                  Text('Store Statistics',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),

                  // Stats grid (Responsive: 1x4 on web/tablet, 2x2 on mobile)
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isWide = constraints.maxWidth >= 600;
                      return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isWide ? 4 : 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: isWide ? 2.2 : 1.6,
                          children: [
                            _StatTile('Total Products', '${dash.totalProducts}',
                                Icons.inventory_2_outlined, AppColors.primary),
                            _StatTile('Total Revenue', currency.format(salesP.totalRevenue),
                                Icons.point_of_sale_outlined, AppColors.success),
                            _StatTile('Stock Value', currency.format(dash.totalStockValue),
                                Icons.account_balance_wallet_outlined,
                                const Color(0xFF1565C0)),
                            _StatTile('Total Sales', '${salesP.totalTxns}',
                                Icons.receipt_long_outlined,
                                const Color(0xFF7B1FA2)),
                          ]);
                    },
                  ),

                  const SizedBox(height: 20),
                  Text('Settings',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),

                  // Settings options
                  _InfoCard(children: [
                    _ActionRow(
                        icon: Icons.notifications_outlined,
                        color: AppColors.warning,
                        label: 'Alert Thresholds',
                        subtitle: 'Low stock & expiry settings',
                        onTap: () => _showAlertSettings(context)),
                    const Divider(color: AppColors.divider, height: 1),
                    _ActionRow(
                        icon: Icons.info_outline,
                        color: AppColors.primary,
                        label: 'App Version',
                        subtitle: 'StockMate Pro v1.0.0',
                        onTap: null),
                  ]),

                  const SizedBox(height: 20),

                  // Logout button
                  SizedBox(
                      width: double.infinity, height: 50,
                      child: OutlinedButton.icon(
                          onPressed: () => _logout(context),
                          icon: const Icon(Icons.logout, color: AppColors.danger),
                          label: const Text('Logout',
                              style: TextStyle(color: AppColors.danger,
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.danger, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))))),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Logout',
                      style: TextStyle(color: AppColors.danger,
                          fontWeight: FontWeight.w600))),
            ]));

    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false);
      }
    }
  }

  void _showAlertSettings(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const _AlertSettingsSheet());
  }
}

// ── Info Card ─────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
              blurRadius: 4, offset: const Offset(0, 1))]),
      child: Column(children: children));
}

// ── Info Row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(width: 34, height: 34,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.primary, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11,
                  color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ])),
      ]));
}

// ── Action Row ────────────────────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, subtitle;
  final VoidCallback? onTap;
  const _ActionRow({required this.icon, required this.color,
    required this.label, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(width: 34, height: 34,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(fontSize: 11,
                      color: AppColors.textSecondary)),
                ])),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
          ])));
}

// ── Stat Tile ─────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
              blurRadius: 4, offset: const Offset(0, 1))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10,
                color: AppColors.textSecondary)),
          ]));
}

// ── Alert Settings Sheet ──────────────────────────────────────────────────────
class _AlertSettingsSheet extends StatelessWidget {
  const _AlertSettingsSheet();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Container(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Alert Settings', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                const Text('These thresholds are set per product when adding/editing.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 20),
                _settingRow('Low Stock Alert',
                    'Set per product → "Low Stock Alert At" field',
                    Icons.inventory_outlined, AppColors.warning),
                const SizedBox(height: 12),
                _settingRow('Expiry Alert',
                    'Auto-triggered 7 days before expiry date',
                    Icons.hourglass_bottom_outlined, AppColors.danger),
                const SizedBox(height: 12),
                _settingRow('Out of Stock Alert',
                    'Auto-triggered when quantity reaches 0',
                    Icons.remove_shopping_cart_outlined,
                    const Color(0xFF1565C0)),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity,
                    child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'))),
              ])),
    ),
  );

  Widget _settingRow(String title, String desc, IconData icon, Color color) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600,
                  fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 12,
                  color: AppColors.textSecondary)),
            ])),
      ]);
}