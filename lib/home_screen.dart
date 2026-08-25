// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'product.dart';
import 'providers.dart';
import 'products_screen.dart';
import 'alerts_screen.dart';
import 'sales_screen.dart';
import 'add_product_screen.dart';
import 'account.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _pages = const [
    _DashboardTab(), ProductsScreen(), AlertsScreen(), SalesScreen(), AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<ProductProvider>().alertCount;
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddProductScreen()));
            if (mounted) {
              final uid = context.read<AuthProvider>().userId;
              await context.read<ProductProvider>().load(uid);
              await context.read<DashboardProvider>().load(uid);
            }
          },
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Product',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
              label: 'Dashboard'),
          const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
              label: 'Products'),
          NavigationDestination(
              icon: Badge(isLabelVisible: alerts > 0, label: Text('$alerts'),
                  child: const Icon(Icons.notifications_outlined)),
              selectedIcon: Badge(isLabelVisible: alerts > 0, label: Text('$alerts'),
                  child: const Icon(Icons.notifications, color: AppColors.primary)),
              label: 'Alerts'),
          const NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart, color: AppColors.primary),
              label: 'Sales'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Account'),
        ],
      ),
    );
  }
}

// ── Dashboard Tab ──────────────────────────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final dash     = context.watch<DashboardProvider>();
    final auth     = context.watch<AuthProvider>();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: dash.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          final uid = context.read<AuthProvider>().userId;
          await Future.wait([
            context.read<DashboardProvider>().load(uid),
            context.read<ProductProvider>().load(uid),
          ]);
        },
        child: CustomScrollView(slivers: [
          // App bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false, pinned: true,
            backgroundColor: AppColors.primary,
            actions: [
              IconButton(
                  icon: const Icon(Icons.refresh_outlined, color: Colors.white),
                  onPressed: () async {
                    final uid = context.read<AuthProvider>().userId;
                    await Future.wait([
                      context.read<DashboardProvider>().load(uid),
                      context.read<ProductProvider>().load(uid),
                    ]);
                  }),
            ],
            flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                          begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(children: [
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Good ${_greeting()}, ${auth.userName}! 👋',
                                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(auth.storeName,
                                      style: const TextStyle(color: Colors.white,
                                          fontSize: 20, fontWeight: FontWeight.w800)),
                                ])),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Row(children: [
                                  const Icon(Icons.calendar_today_outlined,
                                      color: Colors.white70, size: 14),
                                  const SizedBox(width: 6),
                                  Text(DateFormat('d MMM yyyy').format(DateTime.now()),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ])),
                          ]),
                        ]),
                  ),
                )),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Stat cards (Responsive: 1x4 on web/tablet, 2x2 on mobile)
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                        if (isWide) {
                          return Row(children: [
                            Expanded(child: _StatCard('Total Products',
                                '${dash.totalProducts}',
                                Icons.inventory_2_outlined, AppColors.primary,
                                AppColors.primary.withOpacity(0.08))),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard("Today's Sales",
                                currency.format(dash.todayRevenue),
                                Icons.point_of_sale_outlined, AppColors.success,
                                AppColors.success.withOpacity(0.08))),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard('Stock Value',
                                currency.format(dash.totalStockValue),
                                Icons.account_balance_wallet_outlined,
                                const Color(0xFF1565C0),
                                const Color(0xFF1565C0).withOpacity(0.08))),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard('Active Alerts',
                                '${dash.totalAlerts}',
                                Icons.notifications_active_outlined,
                                AppColors.warning, AppColors.warning.withOpacity(0.08),
                                highlight: dash.totalAlerts > 0)),
                          ]);
                        }
                        return Column(children: [
                          Row(children: [
                            Expanded(child: _StatCard('Total Products',
                                '${dash.totalProducts}',
                                Icons.inventory_2_outlined, AppColors.primary,
                                AppColors.primary.withOpacity(0.08))),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard("Today's Sales",
                                currency.format(dash.todayRevenue),
                                Icons.point_of_sale_outlined, AppColors.success,
                                AppColors.success.withOpacity(0.08))),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _StatCard('Stock Value',
                                currency.format(dash.totalStockValue),
                                Icons.account_balance_wallet_outlined,
                                const Color(0xFF1565C0),
                                const Color(0xFF1565C0).withOpacity(0.08))),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard('Active Alerts',
                                '${dash.totalAlerts}',
                                Icons.notifications_active_outlined,
                                AppColors.warning, AppColors.warning.withOpacity(0.08),
                                highlight: dash.totalAlerts > 0)),
                          ]),
                        ]);
                      },
                    ),

                    // Alert banner
                    if (dash.totalAlerts > 0) ...[
                      const SizedBox(height: 18),
                      _AlertBanner(
                          lowStock: dash.lowStockCount,
                          expired: dash.expiredCount,
                          expiringSoon: dash.expiringSoonCount),
                    ],

                    const SizedBox(height: 24),
                    Text('Browse by Category',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    _CategoryGrid(catCounts: dash.catCounts),

                    const SizedBox(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Recent Sales',
                          style: Theme.of(context).textTheme.headlineMedium),
                      Text('${dash.recentSales.length} transactions',
                          style: const TextStyle(color: AppColors.textSecondary,
                              fontSize: 12)),
                    ]),
                    const SizedBox(height: 10),

                    if (dash.recentSales.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider.withOpacity(0.5)),
                        ),
                        child: const Center(
                          child: Text('No sales recorded yet',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ),
                      )
                    else
                      ...dash.recentSales.map((s) => _RecentSaleCard(sale: s)),

                    const SizedBox(height: 80),
                  ]),
                ),
          ),
        ]),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconColor, bgColor;
  final bool highlight;
  const _StatCard(this.label, this.value, this.icon, this.iconColor, this.bgColor,
      {this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: highlight ? Border.all(color: AppColors.warning, width: 1.5) : Border.all(color: AppColors.divider.withOpacity(0.4)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
          blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 34, height: 34,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 18)),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
          color: highlight ? AppColors.warning : AppColors.textPrimary)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]),
  );
}

class _AlertBanner extends StatelessWidget {
  final int lowStock, expired, expiringSoon;
  const _AlertBanner({required this.lowStock, required this.expired, required this.expiringSoon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
        const SizedBox(width: 8),
        const Text('Attention Required',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.warning)),
      ]),
      const SizedBox(height: 8),
      if (expired > 0) _row(Icons.dangerous_outlined, AppColors.danger,
          '$expired product(s) have expired'),
      if (expiringSoon > 0) _row(Icons.hourglass_bottom_outlined, AppColors.warning,
          '$expiringSoon expiring within 7 days'),
      if (lowStock > 0) _row(Icons.inventory_outlined, const Color(0xFF1565C0),
          '$lowStock item(s) low on stock'),
    ]),
  );

  Widget _row(IconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(icon, color: color, size: 15), const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]));
}

class _CategoryGrid extends StatelessWidget {
  final Map<String, int> catCounts;
  const _CategoryGrid({required this.catCounts});

  @override
  Widget build(BuildContext context) {
    final cats = [
      {'name': 'Grocery',    'key': 'grocery',    'emoji': '🛒'},
      {'name': 'Dairy',      'key': 'dairy',      'emoji': '🥛'},
      {'name': 'Toiletries', 'key': 'toiletries', 'emoji': '🧴'},
      {'name': 'Beverages',  'key': 'beverages',  'emoji': '🥤'},
      {'name': 'Snacks',     'key': 'snacks',     'emoji': '🍪'},
      {'name': 'Other',      'key': 'other',      'emoji': '📦'},
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final crossCount = constraints.maxWidth >= 850
            ? 6
            : (constraints.maxWidth >= 550 ? 4 : 3);
        final ratio = constraints.maxWidth >= 850
            ? 1.4
            : (constraints.maxWidth >= 550 ? 1.3 : 1.15);

        return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cats.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: ratio,
            ),
            itemBuilder: (ctx, i) {
              final c = cats[i];
              final count = catCounts[c['key']] ?? 0;
              final color = AppColors.categoryColors[c['key']] ?? AppColors.primary;
              return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.18))),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c['emoji']!, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(c['name']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w600, color: color)),
                        Text('$count items',
                            style: TextStyle(fontSize: 10,
                                color: color.withOpacity(0.7))),
                      ]));
            });
      },
    );
  }
}

class _RecentSaleCard extends StatelessWidget {
  final Sale sale;
  const _RecentSaleCard({required this.sale});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
            blurRadius: 4, offset: const Offset(0, 1))]),
    child: Row(children: [
      Container(width: 38, height: 38,
          decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.shopping_bag_outlined,
              color: AppColors.success, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(sale.productName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text('Qty: ${sale.quantitySold} • ${DateFormat('d MMM, h:mm a').format(sale.saleDate)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ])),
      Text('₹${sale.totalAmount.toStringAsFixed(0)}',
          style: const TextStyle(color: AppColors.success,
              fontWeight: FontWeight.w700, fontSize: 14)),
    ]),
  );
}