import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:rephelp/data/app_database.dart';

class IncomeStatisticsScreen extends StatefulWidget {
  const IncomeStatisticsScreen({super.key});

  @override
  State<IncomeStatisticsScreen> createState() => _IncomeStatisticsScreenState();
}

class _IncomeStatisticsScreenState extends State<IncomeStatisticsScreen> {
  final AppDatabase _database = AppDatabase();
  List<Map<String, dynamic>> _incomeData = [];
  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _setInitialDateRangeAndLoadData();
  }

  void _setInitialDateRangeAndLoadData() {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
    _loadIncomeData(initialRange);
  }

  Future<void> _loadIncomeData(DateTimeRange dateRange) async {
    setState(() {
      _isLoading = true;
      _selectedDateRange = dateRange;
    });

    final data = await _database.getFinancialDataByDateRange(
      dateRange.start,
      dateRange.end,
    );

    if (mounted) {
      setState(() {
        _incomeData = data;
        _isLoading = false;
      });
    }
  }

  Map<String, double> _groupDataByMonth() {
    final Map<String, double> monthlyTotals = {};
    for (var item in _incomeData) {
      final date = DateTime.fromMillisecondsSinceEpoch(item['start_time']);
      final monthKey = DateFormat.yMMM('ru').format(date);
      final price = (item['price'] as num).toDouble();
      monthlyTotals.update(monthKey, (value) => value + price,
          ifAbsent: () => price);
    }
    return monthlyTotals;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDateFilterButtons(),
                Expanded(child: _buildChart()),
                _buildTotalIncome(),
              ],
            ),
    );
  }

  Widget _buildDateFilterButtons() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.center,
        children: [
          _buildFilterChip("Текущий месяц", _selectCurrentMonth),
          _buildFilterChip("Последние 3 месяца", _selectLast3Months),
          _buildFilterChip("Последние 6 месяцев", _selectLast6Months),
          _buildFilterChip("За все время", _selectAllTime),
          _buildFilterChip("Выбрать диапазон", _selectCustomDateRange),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onSelected) {
    return ActionChip(
      label: Text(label),
      onPressed: onSelected,
      backgroundColor: Colors.blue.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.blue, width: 1),
      ),
    );
  }

  void _selectCurrentMonth() {
    final now = DateTime.now();
    _loadIncomeData(DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    ));
  }

  void _selectLast3Months() {
    final now = DateTime.now();
    _loadIncomeData(DateTimeRange(
      start: DateTime(now.year, now.month - 3, now.day),
      end: now,
    ));
  }

  void _selectLast6Months() {
    final now = DateTime.now();
    _loadIncomeData(DateTimeRange(
      start: DateTime(now.year, now.month - 6, now.day),
      end: now,
    ));
  }

  void _selectAllTime() {
    _loadIncomeData(DateTimeRange(
      start: DateTime(2000),
      end: DateTime.now(),
    ));
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      _loadIncomeData(picked);
    }
  }

  Widget _buildChart() {
    final monthlyData = _groupDataByMonth();
    if (monthlyData.isEmpty) {
      return const Center(child: Text("Нет данных за выбранный период"));
    }

    final barGroups = monthlyData.entries.map((entry) {
      final index = monthlyData.keys.toList().indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: Colors.blue,
            width: 16,
          )
        ],
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (monthlyData.values.reduce((a, b) => a > b ? a : b) * 1.2),
          barGroups: barGroups,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < monthlyData.keys.length) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 8.0,
                      child: Text(
                        monthlyData.keys.elementAt(index),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 42,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}');
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalIncome() {
    final total = _incomeData.fold<double>(
        0.0, (sum, item) => sum + (item['price'] as num));
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Общий доход: ",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${total.toStringAsFixed(0)} руб.',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
