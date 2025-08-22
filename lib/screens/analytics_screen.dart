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
  int _totalLessons = 0;
  int _totalStudents = 0;
  double _totalEarned = 0.0;
  double _averagePrice = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    final lessons = await _database.getAllLessons();
    final students = await _database.getStudents(isArchived: false);
    final financialData = await _database.getFinancialData();

    double totalRevenue = 0.0;
    for (var lesson in financialData) {
      totalRevenue += (lesson['price'] as num).toDouble();
    }

    if (!mounted) return;
    setState(() {
      _totalLessons = lessons.length;
      _totalStudents = students.length;
      _totalEarned = totalRevenue;
      _averagePrice = _totalLessons > 0 ? _totalEarned / _totalLessons : 0.0;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Аналитика'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalyticsData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildStatCard(
                    'Всего проведено занятий',
                    _totalLessons.toString(),
                    Icons.class_outlined,
                  ),
                  _buildStatCard(
                    'Активных учеников',
                    _totalStudents.toString(),
                    Icons.people_outline,
                  ),
                  _buildStatCard(
                    'Общий доход',
                    '${_totalEarned.toStringAsFixed(0)} руб.',
                    Icons.monetization_on_outlined,
                  ),
                  _buildStatCard(
                    'Средняя цена занятия',
                    '${_averagePrice.toStringAsFixed(0)} руб.',
                    Icons.price_check_outlined,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
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
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
