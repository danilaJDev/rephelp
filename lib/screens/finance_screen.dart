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
  Map<String, List<Map<String, dynamic>>> _groupedFinancialData = {};
  double _totalEarned = 0.0;
  double _unpaidAmount = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData({bool withSpinner = true}) async {
    if (withSpinner) {
      if (!mounted) return;
      setState(() => _isLoading = true);
    }

    var allLessons = await _database.getFinancialData();
    final now = DateTime.now();
    bool updated = false;

    for (final lesson in allLessons) {
      final endTime = DateTime.fromMillisecondsSinceEpoch(lesson['end_time']);
      final isPaid = lesson['is_paid'] == 1;
      final autoPay = lesson['autoPay'] == 1;

      if (autoPay && !isPaid && endTime.isBefore(now)) {
        await _database.updateLessonIsPaid(lesson['id'] as int, true);
        updated = true;
      }
    }

    if (updated) {
      allLessons = await _database.getFinancialData();
    }

    final pastLessons = allLessons.where((lesson) {
      final endTime = DateTime.fromMillisecondsSinceEpoch(lesson['end_time']);
      return endTime.isBefore(now);
    }).toList();

    double total = 0.0;
    double unpaid = 0.0;
    Map<String, List<Map<String, dynamic>>> groupedData = {};

    for (var lesson in pastLessons) {
      final price = (lesson['price'] as num).toDouble();
      final isPaid = lesson['is_paid'] == 1;

      if (isPaid) {
        total += price;
      } else {
        unpaid += price;
      }

      final studentName = '${lesson['name']} ${lesson['surname'] ?? ''}';
      groupedData.putIfAbsent(studentName, () => []).add(lesson);
    }

    if (!mounted) return;
    setState(() {
      _groupedFinancialData = groupedData;
      _totalEarned = total;
      _unpaidAmount = unpaid;
      if (withSpinner) _isLoading = false; // не трогаем, если тихая загрузка
    });
  }

  Future<void> _toggleLessonPaidStatus(int lessonId, bool isPaid) async {
    await _database.updateLessonIsPaid(lessonId, !isPaid);
    // Тихое обновление — без спиннера, чтобы не схлопывались ExpansionTile
    await _loadFinancialData(withSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Text('Финансы', style: TextStyle(fontSize: 24)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadFinancialData(withSpinner: false),
              child: Column(
                children: [
                  _buildSummaryCard(),
                  Expanded(child: _buildFinancialList()),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(
              'Всего заработано',
              '${_totalEarned.toStringAsFixed(0)} руб.',
              Colors.green,
              Icons.account_balance_wallet,
            ),
            _buildSummaryItem(
              'Ожидается оплата',
              '${_unpaidAmount.toStringAsFixed(0)} руб.',
              Colors.orange,
              Icons.hourglass_bottom,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialList() {
    if (_groupedFinancialData.isEmpty) {
      return const Center(
        child: Text(
          'Проведенных занятий пока нет',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final studentNames = _groupedFinancialData.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: studentNames.length,
      itemBuilder: (context, index) {
        final studentName = studentNames[index];
        final lessons = _groupedFinancialData[studentName]!;

        // Новые сверху
        lessons.sort(
          (a, b) => (b['start_time'] as int).compareTo(a['start_time'] as int),
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            key: PageStorageKey<String>('finance_$studentName'),
            maintainState: true,
            title: Text(
              studentName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            children: lessons.map((lesson) {
              final startTime = DateTime.fromMillisecondsSinceEpoch(
                lesson['start_time'],
              );
              final endTime = DateTime.fromMillisecondsSinceEpoch(
                lesson['end_time'],
              );
              final isPaid = lesson['is_paid'] == 1;
              final lessonDate = DateFormat.yMMMd('ru').format(startTime);
              final lessonTime =
                  '${DateFormat.Hm('ru').format(startTime)} - ${DateFormat.Hm('ru').format(endTime)}';
              final price = (lesson['price'] as num).toStringAsFixed(0);

              final cardColor = isPaid ? Colors.green[50] : Colors.red[50];
              final statusText = isPaid ? 'Оплачено' : 'Ожидает оплаты';
              final statusColor = isPaid ? Colors.green : Colors.red;

              return Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: isPaid
                        ? Colors.green[100]
                        : Colors.orange[100],
                    child: Icon(
                      isPaid ? Icons.check_circle : Icons.hourglass_bottom,
                      color: isPaid ? Colors.green : Colors.orange,
                      size: 22,
                    ),
                  ),
                  tileColor: isPaid ? Colors.green[50] : Colors.orange[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lessonDate,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lessonTime,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  trailing: Text(
                    '$price руб.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: statusColor,
                    ),
                  ),
                  onTap: () {
                    _toggleLessonPaidStatus(lesson['id'] as int, isPaid);
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
