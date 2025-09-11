import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rephelp/data/app_database.dart';

class IncomeStatisticsScreen extends StatefulWidget {
  const IncomeStatisticsScreen({Key? key}) : super(key: key);

  @override
  State<IncomeStatisticsScreen> createState() => _IncomeStatisticsScreenState();
}

class _IncomeStatisticsScreenState extends State<IncomeStatisticsScreen> {
  final AppDatabase _database = AppDatabase();
  List<Map<String, dynamic>> _incomeData = [];
  bool _isLoading = true;

  String _selectedFilter = 'Доходы за 3 месяца';
  bool _panelOpen = false;
  double _prevTotal = 0;

  final Map<String, DateTimeRange> _dateFilters = {
    'Доходы за 3 месяца': DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month - 2, 1),
      end: DateTime.now(),
    ),
    'Доходы за 6 месяцев': DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month - 5, 1),
      end: DateTime.now(),
    ),
    'Доходы за 12 месяцев': DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month - 11, 1),
      end: DateTime.now(),
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadIncomeData(_dateFilters[_selectedFilter]!);
  }

  Future<void> _loadIncomeData(DateTimeRange range) async {
    setState(() => _isLoading = true);
    final data = await _database.getFinancialDataByDateRange(
      range.start,
      range.end,
    );
    if (!mounted) return;

    final monthly = _groupByMonth(range);
    final total = monthly.values.fold(0.0, (a, b) => a + b);
    _prevTotal = _prevTotal == 0 ? total : _prevTotal;

    setState(() {
      _incomeData = data;
      _isLoading = false;
    });
  }

  Map<String, double> _groupByMonth(DateTimeRange range) {
    final Map<String, double> result = {};
    var cursor = DateTime(range.start.year, range.start.month);
    final end = DateTime(range.end.year, range.end.month);

    while (!cursor.isAfter(end)) {
      final label = DateFormat.MMM('ru').format(cursor).toUpperCase();
      result[label] = 0;
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    for (var row in _incomeData) {
      final dt = DateTime.fromMillisecondsSinceEpoch(row['start_time']);
      final key = DateFormat.MMM('ru').format(dt).toUpperCase();
      final price = (row['price'] as num).toDouble();
      if (result.containsKey(key)) result[key] = result[key]! + price;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final range = _dateFilters[_selectedFilter]!;
    final monthly = _groupByMonth(range);
    final total = monthly.values.fold(0.0, (a, b) => a + b);
    final maxMonth = monthly.values.fold<double>(
      0.0,
      (mx, v) => v > mx ? v : mx,
    );

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  _buildFilterPanel(),
                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: _prevTotal, end: total),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return _buildSummaryCard(value);
                      },
                      onEnd: () => _prevTotal = total,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      child: Padding(
                        key: ValueKey(_selectedFilter),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildMonthlyList(monthly, maxMonth),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterPanel() {
    final current = _selectedFilter;
    final others = _dateFilters.keys.where((k) => k != current).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0, // убрали тень
        child: ExpansionTile(
          key: ValueKey(current),
          leading: const Icon(Icons.date_range, color: Colors.deepPurple),
          title: Text(
            current,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          initiallyExpanded: _panelOpen,
          onExpansionChanged: (open) => setState(() => _panelOpen = open),
          children: [
            const Divider(height: 1, thickness: 1, color: Colors.deepPurple),
            ...others.map((label) {
              return Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.date_range, color: Colors.grey),
                    title: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedFilter = label;
                        _panelOpen = false;
                      });
                      _loadIncomeData(_dateFilters[label]!);
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.deepPurple,
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double total) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 100),
        child: Column(
          children: [
            const Text(
              'Общий доход',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              '${total.toStringAsFixed(0)} руб',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyList(Map<String, double> data, double max) {
    final months = data.keys.toList();
    return ListView.separated(
      itemCount: months.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final label = months[i];
        final value = data[label]!;
        final ratio = max > 0 ? (value / max) : 0.0;

        return Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),

            SizedBox(
              width: 200,
              child: Stack(
                children: [
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    height: 16,
                    width: 200 * ratio,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
              width: 100,
              child: Text(
                '${value.toStringAsFixed(0)} руб',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
