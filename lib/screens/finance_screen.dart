import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:intl/intl.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final AppDatabase _database = AppDatabase();
  List<Map<String, dynamic>> _financialData = [];
  double _totalEarned = 0.0;
  double _unpaidAmount = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() {
      _isLoading = true;
    });

    final data = await _database.getFinancialData();
    double total = 0.0;
    double unpaid = 0.0;

    for (var lesson in data) {
      final price = lesson['price'] as double;
      final isPaid = lesson['is_paid'] == 1;
      total += price;
      if (!isPaid) {
        unpaid += price;
      }
    }

    setState(() {
      _financialData = data;
      _totalEarned = total;
      _unpaidAmount = unpaid;
      _isLoading = false;
    });
  }

  Future<void> _togglePaidStatus(int lessonId, bool currentStatus) async {
    await _database.updateLessonIsPaid(lessonId, !currentStatus);
    _loadFinancialData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Блок с общей финансовой статистикой
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.blueGrey,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'Общий доход',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(
                            '${_totalEarned.toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text(
                            'Неоплачено',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(
                            '${_unpaidAmount.toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Список занятий
                Expanded(
                  child: _financialData.isEmpty
                      ? const Center(child: Text('Нет данных о занятиях.'))
                      : ListView.builder(
                          itemCount: _financialData.length,
                          itemBuilder: (context, index) {
                            final lesson = _financialData[index];
                            final lessonId = lesson['id'] as int;
                            final isPaid = lesson['is_paid'] == 1;
                            final date = DateTime.fromMillisecondsSinceEpoch(
                              lesson['date'] as int,
                            );

                            return Card(
                              child: ListTile(
                                leading: Checkbox(
                                  value: isPaid,
                                  onChanged: (value) {
                                    _togglePaidStatus(lessonId, isPaid);
                                  },
                                ),
                                title: Text(lesson['name'] as String),
                                subtitle: Text(
                                  '${DateFormat.yMMMd('ru').format(date)} | '
                                  '${(lesson['price'] as double).toStringAsFixed(0)} ₽',
                                ),
                                trailing: isPaid
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                      )
                                    : const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
