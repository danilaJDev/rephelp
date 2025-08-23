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

    final allLessons = await _database.getFinancialData();
    final now = DateTime.now();

    final pastLessons = allLessons.where((lesson) {
      final endTime = DateTime.fromMillisecondsSinceEpoch(lesson['end_time']);
      return endTime.isBefore(now);
    }).toList();

    double total = 0.0;
    double unpaid = 0.0;

    for (var lesson in pastLessons) {
      final price = (lesson['price'] as num).toDouble();
      final isPaid = lesson['is_paid'] == 1;
      total += price;
      if (!isPaid) {
        unpaid += price;
      }
    }

    if (!mounted) return;
    setState(() {
      _financialData = pastLessons;
      _totalEarned = total;
      _unpaidAmount = unpaid;
      _isLoading = false;
    });
  }

  Future<void> _toggleLessonPaidStatus(int lessonId, bool isPaid) async {
    await _database.updateLessonIsPaid(lessonId, !isPaid);
    await _loadFinancialData();
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
              onRefresh: _loadFinancialData,
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
    if (_financialData.isEmpty) {
      return const Center(
        child: Text(
          'Проведенных занятий пока нет',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _financialData.length,
      itemBuilder: (context, index) {
        final lesson = _financialData[index];
        final startTime =
            DateTime.fromMillisecondsSinceEpoch(lesson['start_time']);
        final endTime = DateTime.fromMillisecondsSinceEpoch(lesson['end_time']);
        final isPaid = lesson['is_paid'] == 1;
        final studentName =
            '${lesson['name']} ${lesson['surname'] ?? ''}';
        final lessonDate = DateFormat.yMMMd('ru').format(startTime);
        final lessonTime =
            '${DateFormat.Hm('ru').format(startTime)} - ${DateFormat.Hm('ru').format(endTime)}';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: CheckboxListTile(
            value: isPaid,
            onChanged: (bool? value) {
              if (value != null) {
                _toggleLessonPaidStatus(lesson['id'] as int, isPaid);
              }
            },
            title: Text(
              studentName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('$lessonDate\n$lessonTime'),
            secondary: Text(
              '${(lesson['price'] as num).toStringAsFixed(0)} руб.',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Colors.green,
          ),
        );
      },
    );
  }
}
