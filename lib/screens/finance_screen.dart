import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:intl/intl.dart';
import 'package:rephelp/widgets/custom_app_bar.dart';

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
      try {
        final price = lesson['price'] as double;
        final isPaid = lesson['is_paid'] == 1;
        total += price;
        if (!isPaid) {
          unpaid += price;
        }
      } catch (e) {
        print('Error processing financial data for lesson: $e');
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
      appBar: const CustomAppBar(title: 'Финансы'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
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
                              color: Colors.amberAccent,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _financialData.isEmpty
                      ? const Center(child: Text('Нет данных о занятиях.'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 10.0),
                          itemCount: _financialData.length,
                          itemBuilder: (context, index) {
                            try {
                              final lesson = _financialData[index];
                              final lessonId = lesson['id'] as int;
                              final isPaid = lesson['is_paid'] == 1;
                              final date = DateTime.fromMillisecondsSinceEpoch(
                              lesson['start_time'] as int,
                              );

                              return Card(
                                color: Colors.white,
                              margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              child: ListTile(
                                onTap: () => _togglePaidStatus(lessonId, isPaid),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isPaid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isPaid ? Icons.check : Icons.close,
                                    color: isPaid ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(
                                  lesson['name'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  DateFormat.yMMMd('ru').format(date),
                                ),
                                trailing: Text(
                                  '${(lesson['price'] as double).toStringAsFixed(0)} ₽',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                            } catch (e) {
                              print('Error building lesson card: $e');
                              return const SizedBox.shrink(); // Or some error widget
                            }
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
