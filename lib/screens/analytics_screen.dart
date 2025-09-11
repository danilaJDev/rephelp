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
  int _conductedLessons = 0;
  int _totalStudents = 0;
  int _activeStudents = 0;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    final activeStudentsList = await _database.getStudents(isArchived: false);
    final archivedStudentsList = await _database.getStudents(isArchived: true);
    final allStudents = [...activeStudentsList, ...archivedStudentsList];
    final financialData = await _database.getFinancialData();

    int conductedLessonsCount = 0;
    double totalRevenueValue = 0.0;

    final now = DateTime.now();

    for (var lessonData in financialData) {
      final startTime = DateTime.fromMillisecondsSinceEpoch(
        lessonData['start_time'] as int,
      );
      final isPaid = (lessonData['is_paid'] as int) == 1;
      final price = (lessonData['price'] as num).toDouble();

      if (isPaid && startTime.isBefore(now)) {
        conductedLessonsCount++;
      }

      if (isPaid) {
        totalRevenueValue += price;
      }
    }

    if (!mounted) return;
    setState(() {
      _conductedLessons = conductedLessonsCount;
      _totalStudents = allStudents.length;
      _activeStudents = activeStudentsList.length;
      _totalRevenue = totalRevenueValue;
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
      body: Column(
        children: [
          Container(
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAnalyticsData,
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        _buildStatCard(
                          'Проведено занятий',
                          _conductedLessons.toString(),
                          Icons.class_outlined,
                        ),
                        _buildStatCard(
                          'Всего учеников',
                          _totalStudents.toString(),
                          Icons.people_alt_outlined,
                        ),
                        _buildStatCard(
                          'Активных учеников',
                          _activeStudents.toString(),
                          Icons.people_outline,
                        ),
                        _buildStatCard(
                          'Доход за всё время',
                          '${_totalRevenue.toStringAsFixed(0)} руб.',
                          Icons.monetization_on_outlined,
                        ),
                      ],
                    ),
                  ),
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
