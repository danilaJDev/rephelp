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
    setState(() {
      _isLoading = true;
    });

    final lessons = await _database.getAllLessons();
    final students = await _database.getStudents();
    final financialData = await _database.getFinancialData();

    double totalRevenue = 0.0;
    for (var lesson in financialData) {
      try {
        totalRevenue += lesson['price'] as double;
      } catch (e) {
        print('Error processing financial data for analytics: $e');
      }
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
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Общая статистика',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(10.0),
                    children: [
                      _buildStatCard(
                        'Всего занятий',
                        _totalLessons.toString(),
                        Icons.school_outlined,
                      ),
                      _buildStatCard(
                        'Всего учеников',
                        _totalStudents.toString(),
                        Icons.people_outline,
                      ),
                      _buildStatCard(
                        'Общий доход',
                        '${_totalEarned.toStringAsFixed(0)} ₽',
                        Icons.monetization_on_outlined,
                      ),
                      _buildStatCard(
                        'Средняя цена',
                        '${_averagePrice.toStringAsFixed(0)} ₽',
                        Icons.price_check_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 24, color: Colors.deepPurple),
        ),
        title: Text(title, style: const TextStyle(color: Colors.black)),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
