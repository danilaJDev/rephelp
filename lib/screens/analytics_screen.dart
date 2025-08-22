import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/utils/app_colors.dart';
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
    setState(() {
      _isLoading = true;
    });

    final lessons = await _database.getAllLessons();
    final students = await _database.getStudents();
    final financialData = await _database.getFinancialData();

    double totalRevenue = 0.0;
    for (var lesson in financialData) {
      totalRevenue += lesson['price'] as double;
    }

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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildStatCard(
                    'Всего занятий',
                    _totalLessons.toString(),
                    Icons.school,
                  ),
                  _buildStatCard(
                    'Всего учеников',
                    _totalStudents.toString(),
                    Icons.people,
                  ),
                  _buildStatCard(
                    'Общий доход',
                    '${_totalEarned.toStringAsFixed(0)} ₽',
                    Icons.monetization_on,
                  ),
                  _buildStatCard(
                    'Средняя цена',
                    '${_averagePrice.toStringAsFixed(0)} ₽',
                    Icons.attach_money,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: AppColors.lavender),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
