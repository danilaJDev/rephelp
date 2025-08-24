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
  String _selectedFilter = 'Квартал';

  final Map<String, DateTimeRange> _dateFilters = {
    'Квартал': DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month - 2, 1),
      end: DateTime.now(),
    ),
    'Полгода': DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month - 5, 1),
      end: DateTime.now(),
    ),
    'Год': DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month - 11, 1),
      end: DateTime.now(),
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadIncomeData(_dateFilters[_selectedFilter]!);
  }

  Future<void> _loadIncomeData(DateTimeRange dateRange) async {
    setState(() => _isLoading = true);

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

  Map<String, double> _groupDataByMonthWithAll(DateTimeRange range) {
    final Map<String, double> monthlyTotals = {};
    DateTime current = DateTime(range.start.year, range.start.month);
    final end = DateTime(range.end.year, range.end.month);

    while (!current.isAfter(end)) {
      final monthKey = DateFormat.MMM('ru').format(current).toUpperCase();
      monthlyTotals[monthKey] = 0.0;
      current = DateTime(current.year, current.month + 1);
    }

    for (var item in _incomeData) {
      final date = DateTime.fromMillisecondsSinceEpoch(item['start_time']);
      final monthKey = DateFormat.MMM('ru').format(date).toUpperCase();
      final price = (item['price'] as num).toDouble();
      if (monthlyTotals.containsKey(monthKey)) {
        monthlyTotals[monthKey] = monthlyTotals[monthKey]! + price;
      }
    }

    return monthlyTotals;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildFilterDropdown(),
                  _buildChartCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterDropdown() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButtonFormField<String>(
            value: _selectedFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(
                Icons.calendar_today_outlined,
                color: Colors.black54,
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            items: _dateFilters.keys.map((filter) {
              return DropdownMenuItem(
                value: filter,
                child: Row(
                  children: [
                    const Icon(
                      Icons.date_range,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 12),
                    Text(filter),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedFilter = value);
                _loadIncomeData(_dateFilters[value]!);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final monthlyData = _groupDataByMonthWithAll(
      _dateFilters[_selectedFilter]!,
    );
    final total = _incomeData.fold<double>(
      0.0,
      (sum, item) => sum + (item['price'] as num),
    );
    final maxValue =
        monthlyData.values.fold(0.0, (max, v) => v > max ? v : max);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Доход",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                "${total.toStringAsFixed(0)} ₽",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    maxY: maxValue > 0 ? maxValue * 1.2 : 1,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.shade300,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < monthlyData.keys.length) {
                              return SideTitleWidget(
                                space: 6,
                                meta: meta,
                                child: Text(
                                  monthlyData.keys.elementAt(index),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    barGroups: monthlyData.entries.map((entry) {
                      final index = monthlyData.keys.toList().indexOf(
                        entry.key,
                      );
                      final isEmpty = entry.value == 0;

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value,
                            color: isEmpty
                                ? Colors.grey.shade300
                                : Colors.blue.shade700,
                            width: 36,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                        showingTooltipIndicators: entry.value > 0 ? [0] : [],
                      );
                    }).toList(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.transparent,
                        tooltipPadding: const EdgeInsets.all(0),
                        tooltipMargin: -100,
                        getTooltipItem: (
                          BarChartGroupData group,
                          int groupIndex,
                          BarChartRodData rod,
                          int rodIndex,
                        ) {
                          final amount = rod.toY.toStringAsFixed(0);
                          final verticalAmount = amount.split('').join('\n');
                          return BarTooltipItem(
                            verticalAmount,
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              height: 1.2,
                            ),
                          );
                        },
                      ),
                      touchCallback: (event, response) {
                        // Don't do anything on touch
                      },
                    ),
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 250),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
