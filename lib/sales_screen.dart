// lib/screens/sales/sales_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'providers.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final salesP   = context.watch<SalesProvider>();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Analytics'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent, indicatorWeight: 3,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'History')]),
      ),
      body: TabBarView(controller: _tabs, children: [
        _OverviewTab(salesP: salesP, currency: currency),
        _HistoryTab(salesP: salesP, currency: currency),
      ]),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final SalesProvider salesP;
  final NumberFormat currency;
  const _OverviewTab({required this.salesP, required this.currency});

  @override
  Widget build(BuildContext context) {
    final chartData  = salesP.chartData;
    final maxY       = chartData.fold<double>(
        0, (m, e) => (e['revenue'] as num) > m ? (e['revenue'] as num).toDouble() : m);
    final topProducts= salesP.topProducts;

    return RefreshIndicator(
      onRefresh: () => salesP.load(context.read<AuthProvider>().userId),
      color: AppColors.primary,
      child: salesP.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Summary cards (Responsive: 1x4 on web/tablet, 2x2 on mobile)
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    if (isWide) {
                      return Row(children: [
                        Expanded(child: _SummaryCard("Today's Revenue",
                            currency.format(salesP.todayRevenue),
                            Icons.today_outlined, AppColors.success)),
                        const SizedBox(width: 12),
                        Expanded(child: _SummaryCard("This Week",
                            currency.format(salesP.weekRevenue),
                            Icons.calendar_view_week_outlined, AppColors.primary)),
                        const SizedBox(width: 12),
                        Expanded(child: _SummaryCard("Total Revenue",
                            currency.format(salesP.totalRevenue),
                            Icons.point_of_sale_outlined, const Color(0xFF7B1FA2))),
                        const SizedBox(width: 12),
                        Expanded(child: _SummaryCard("Transactions",
                            '${salesP.totalTxns}',
                            Icons.receipt_long_outlined, const Color(0xFF0097A7))),
                      ]);
                    }
                    return Column(children: [
                      Row(children: [
                        Expanded(child: _SummaryCard("Today's Revenue",
                            currency.format(salesP.todayRevenue),
                            Icons.today_outlined, AppColors.success)),
                        const SizedBox(width: 12),
                        Expanded(child: _SummaryCard("This Week",
                            currency.format(salesP.weekRevenue),
                            Icons.calendar_view_week_outlined, AppColors.primary)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _SummaryCard("Total Revenue",
                            currency.format(salesP.totalRevenue),
                            Icons.point_of_sale_outlined, const Color(0xFF7B1FA2))),
                        const SizedBox(width: 12),
                        Expanded(child: _SummaryCard("Transactions",
                            '${salesP.totalTxns}',
                            Icons.receipt_long_outlined, const Color(0xFF0097A7))),
                      ]),
                    ]);
                  },
                ),

                const SizedBox(height: 24),
                Text('Last 7 Days Revenue',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                        blurRadius: 6, offset: const Offset(0, 2))]),
                  child: SizedBox(height: 220,
                    child: BarChart(BarChartData(
                      maxY: maxY > 0 ? maxY * 1.3 : 100,
                      gridData: FlGridData(show: true, drawVerticalLine: false,
                        horizontalInterval: maxY > 0 ? maxY / 4 : 25,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: AppColors.divider, strokeWidth: 1)),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true, reservedSize: 48,
                          getTitlesWidget: (v, _) => Text(
                            v >= 1000 ? '₹${(v/1000).toStringAsFixed(1)}k' : '₹${v.toInt()}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= chartData.length) return const SizedBox();
                            final d = DateTime.tryParse(chartData[idx]['date'] ?? '');
                            if (d == null) return const SizedBox();
                            return Padding(padding: const EdgeInsets.only(top: 6),
                              child: Text(DateFormat('E').format(d),
                                  style: const TextStyle(fontSize: 10,
                                      color: AppColors.textSecondary)));
                          })),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false))),
                      barGroups: chartData.asMap().entries.map((e) {
                        final revenue = (e.value['revenue'] as num).toDouble();
                        final isToday = e.key == chartData.length - 1;
                        return BarChartGroupData(x: e.key, barRods: [
                          BarChartRodData(toY: revenue, width: 28,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            color: isToday ? AppColors.primary : AppColors.primaryLight),
                        ]);
                      }).toList(),
                      barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: AppColors.primaryDark,
                        getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                          '₹${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 13)))))),
                  )),

                const SizedBox(height: 24),
                Text('Top Products', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 14),

                if (topProducts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider.withOpacity(0.4)),
                    ),
                    child: const Center(
                      child: Text('No sales data yet',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ),
                  )
                else Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                        blurRadius: 6, offset: const Offset(0, 2))]),
                  child: Column(children: topProducts.asMap().entries.map((e) {
                    final rank  = e.key + 1;
                    final name  = e.value['name'] as String;
                    final rev   = (e.value['revenue'] as num).toDouble();
                    final maxR  = (topProducts.first['revenue'] as num).toDouble();
                    final pct   = maxR > 0 ? rev / maxR : 0.0;
                    return Padding(padding: const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        Container(width: 26, height: 26,
                          decoration: BoxDecoration(
                              color: _rankColor(rank).withOpacity(0.15), shape: BoxShape.circle),
                          child: Center(child: Text('$rank',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                      color: _rankColor(rank))))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Expanded(child: Text(name, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              Text(currency.format(rev),
                                  style: const TextStyle(fontWeight: FontWeight.w700,
                                      color: AppColors.primary, fontSize: 13)),
                            ]),
                            const SizedBox(height: 4),
                            ClipRRect(borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: pct,
                                backgroundColor: AppColors.background,
                                valueColor: AlwaysStoppedAnimation(_rankColor(rank)),
                                minHeight: 5)),
                          ])),
                      ]));
                  }).toList())),

                const SizedBox(height: 80),
              ])),
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFFFB300);
      case 2: return const Color(0xFF9E9E9E);
      case 3: return const Color(0xFF8D6E63);
      default: return AppColors.primary;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _SummaryCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.divider.withOpacity(0.4)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
          blurRadius: 4, offset: const Offset(0, 1))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 34, height: 34,
        decoration: BoxDecoration(color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]));
}

// ── History Tab ───────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final SalesProvider salesP;
  final NumberFormat currency;
  const _HistoryTab({required this.salesP, required this.currency});

  @override
  Widget build(BuildContext context) {
    final sales = salesP.sales;
    if (sales.isEmpty) {
      return const Center(child: Text('No sales recorded yet.',
          style: TextStyle(color: AppColors.textSecondary)));
    }

    // Group by date
    final Map<String, List> grouped = {};
    for (final s in sales) {
      final key = DateFormat('d MMMM yyyy').format(s.saleDate);
      grouped.putIfAbsent(key, () => []).add(s);
    }

    return RefreshIndicator(
      onRefresh: () => salesP.load(context.read<AuthProvider>().userId),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: grouped.entries.map((entry) {
          final dayTotal = entry.value.fold<double>(0, (s, e) => s + e.totalAmount);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary, fontSize: 13)),
                Text(currency.format(dayTotal), style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13)),
              ])),
            ...entry.value.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider.withOpacity(0.4)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
                    blurRadius: 4, offset: const Offset(0, 1))]),
              child: Row(children: [
                Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.shopping_cart_outlined,
                      color: AppColors.success, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.productName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('Qty: ${s.quantitySold} × ₹${s.salePrice.toStringAsFixed(0)}  •  ${DateFormat('h:mm a').format(s.saleDate)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ])),
                Text('₹${s.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w700,
                        color: AppColors.success, fontSize: 14)),
              ]))),
          ]);
        }).toList()));
  }
}
