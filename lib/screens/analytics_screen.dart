import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/widgets/custom_app_bar.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

import 'package:intl/intl.dart';

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final AppDatabase _database = AppDatabase();
  bool _isLoading = true;
  int _completedLessons = 0;
  int _paidLessons = 0;
  int _totalStudents = 0;
  double _earnedIncome = 0.0;
  double _expectedIncome = 0.0;
  Map<String, double> _monthlyIncomeData = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    final students = await _database.getStudents(isArchived: false);
    final financialData = await _database.getFinancialData();

    int completedLessonsCount = 0;
    int paidLessonsCount = 0;
    double totalEarned = 0.0;
    double totalExpected = 0.0;
    Map<String, double> monthlyIncome = {};

    final now = DateTime.now();

    for (var lessonData in financialData) {
      final startTime = DateTime.fromMillisecondsSinceEpoch(
        lessonData['start_time'] as int,
      );
      final endTime = DateTime.fromMillisecondsSinceEpoch(
        lessonData['end_time'] as int,
      );
      final isPaid = (lessonData['is_paid'] as int) == 1;
      final price = (lessonData['price'] as num).toDouble();

      if (isPaid) {
        paidLessonsCount++;
        final monthKey = DateFormat.yMMM('ru').format(startTime);
        monthlyIncome.update(monthKey, (value) => value + price,
            ifAbsent: () => price);
      }

      if (endTime.isBefore(now)) {
        completedLessonsCount++;
        if (isPaid) {
          totalEarned += price;
        } else {
          totalExpected += price;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _completedLessons = completedLessonsCount;
      _paidLessons = paidLessonsCount;
      _totalStudents = students.length;
      _earnedIncome = totalEarned;
      _expectedIncome = totalExpected;
      _monthlyIncomeData = monthlyIncome;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Text('Аналитика', style: TextStyle(fontSize: 24)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(color: Colors.white, width: 3),
                      insets: EdgeInsets.symmetric(horizontal: 100),
                    ),
                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(fontSize: 14),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.analytics),
                        child: Text(
                          'Общая',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Tab(
                        icon: Icon(Icons.monetization_on),
                        child: Text(
                          'Доходы',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGeneralAnalyticsView(),
                      _buildIncomeAnalyticsView(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGeneralAnalyticsView() {
    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStatCard(
            'Проведено занятий',
            _completedLessons.toString(),
            Icons.class_outlined,
          ),
          _buildStatCard(
            'Оплачено занятий',
            _paidLessons.toString(),
            Icons.payment,
          ),
          _buildStatCard(
            'Активных учеников',
            _totalStudents.toString(),
            Icons.people_outline,
          ),
          _buildStatCard(
            'Доход',
            '', // Оставляем пустым, так как будем кастомный trailing
            Icons.monetization_on_outlined,
            trailingWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Получено: ${_earnedIncome.toStringAsFixed(0)} руб.',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Ожидается: ${_expectedIncome.toStringAsFixed(0)} руб.',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeAnalyticsView() {
    if (_monthlyIncomeData.isEmpty) {
      return const Center(
        child: Text('Нет данных о доходах.'),
      );
    }

    final sortedMonths = _monthlyIncomeData.keys.toList()
      ..sort((a, b) {
        final aDate = DateFormat.yMMM('ru').parse(a);
        final bDate = DateFormat.yMMM('ru').parse(b);
        return bDate.compareTo(aDate);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedMonths.length,
      itemBuilder: (context, index) {
        final month = sortedMonths[index];
        final income = _monthlyIncomeData[month]!;
        return _buildStatCard(
          month,
          '${income.toStringAsFixed(0)} руб.',
          Icons.calendar_month,
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon, {
    Widget? trailingWidget,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 28, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        trailing:
            trailingWidget ??
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
      ),
    );
  }
}
