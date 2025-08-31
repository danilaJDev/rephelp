import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/widgets/custom_app_bar.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AppDatabase _database = AppDatabase();
  bool _isLoading = true;
  int _completedLessons = 0;
  int _paidLessons = 0;
  int _totalStudents = 0;
  int _activeStudents = 0;
  double _earnedIncome = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    final allStudents = await _database.getStudents();
    final activeStudents = await _database.getStudents(isArchived: false);
    final financialData = await _database.getFinancialData();

    int completedLessonsCount = 0;
    int paidLessonsCount = 0;
    double totalEarned = 0.0;

    final now = DateTime.now();

    for (var lessonData in financialData) {
      final endTime = DateTime.fromMillisecondsSinceEpoch(
        lessonData['end_time'] as int,
      );
      final isPaid = (lessonData['is_paid'] as int) == 1;
      final price = (lessonData['price'] as num).toDouble();

      if (isPaid) {
        paidLessonsCount++;
        totalEarned += price;
      }

      if (endTime.isBefore(now)) {
        completedLessonsCount++;
      }
    }

    if (!mounted) return;
    setState(() {
      _completedLessons = completedLessonsCount;
      _paidLessons = paidLessonsCount;
      _totalStudents = allStudents.length;
      _activeStudents = activeStudents.length;
      _earnedIncome = totalEarned;
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
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildAnalyticsView(),
                ),
              ],
            ),
    );
  }

  Widget _buildAnalyticsView() {
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
            'Всего учеников',
            _totalStudents.toString(),
            Icons.groups,
          ),
          _buildStatCard(
            'Активных учеников',
            _activeStudents.toString(),
            Icons.people_outline,
          ),
          _buildStatCard(
            'Доход за всё время',
            '${_earnedIncome.toStringAsFixed(0)} руб.',
            Icons.monetization_on_outlined,
          ),
        ],
      ),
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
