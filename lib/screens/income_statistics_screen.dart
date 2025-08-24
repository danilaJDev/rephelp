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
  String _selectedFilter = 'Текущий месяц';

  final Map<String, DateTimeRange> _dateFilters = {
    'Текущий месяц': DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month, 1),
      end: DateTime.now(),
    ),
    'Последние 3 месяца': DateTimeRange(
      start: DateTime(
        DateTime.now().year,
        DateTime.now().month - 3,
        DateTime.now().day,
      ),
      end: DateTime.now(),
    ),
    'Последние 6 месяцев': DateTimeRange(
      start: DateTime(
        DateTime.now().year,
        DateTime.now().month - 6,
        DateTime.now().day,
      ),
      end: DateTime.now(),
    ),
    'За все время': DateTimeRange(start: DateTime(2000), end: DateTime.now()),
  };

  @override
  void initState() {
    super.initState();
    _loadIncomeData(_dateFilters[_selectedFilter]!);
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
                _buildDateFilterDropdown(),
                Expanded(child: _buildChart()),
                _buildTotalIncome(),
              ],
            ),
    );
  }

  Widget _buildDateFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: DropdownButton<String>(
        value: _selectedFilter,
        isExpanded: true,
        items: [
          ..._dateFilters.keys,
          'Выбрать диапазон...',
        ].map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue == null) return;

          if (newValue == 'Выбрать диапазон...') {
            _selectCustomDateRange();
          } else {
            setState(() {
              _selectedFilter = newValue;
            });
            _loadIncomeData(_dateFilters[newValue]!);
          }
        },
      ),
    );
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedFilter = 'Выбрать диапазон...';
      });
      _loadIncomeData(picked);
    }
  }

  Widget _buildChart() {
    final monthlyData = _groupDataByMonth();
    if (monthlyData.isEmpty) {
      return const Center(child: Text("Нет данных за выбранный период"));
    }

    final spots = monthlyData.entries.map((entry) {
      final index = monthlyData.keys.toList().indexOf(entry.key);
      return FlSpot(index.toDouble(), entry.value);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < monthlyData.keys.length) {
                    return SideTitleWidget(
                      meta: meta,
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
                  if (value % 10000 == 0 && value > 0) {
                    return Text('${(value / 1000).toStringAsFixed(0)}k');
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
          ],
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
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
