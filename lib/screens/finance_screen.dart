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
      final price = (lesson['price'] as num).toDouble();
      final isPaid = lesson['is_paid'] == 1;
      total += price;
      if (!isPaid) {
        unpaid += price;
      }
    }

    data.sort(
      (a, b) => (b['start_time'] as int).compareTo(a['start_time'] as int),
    );

    if (!mounted) return;
    setState(() {
      _financialData = data;
      _totalEarned = total;
      _unpaidAmount = unpaid;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Финансы'),
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
              '${_totalEarned.toStringAsFixed(0)} ₽',
              Colors.green,
            ),
            _buildSummaryItem(
              'Ожидается оплата',
              '${_unpaidAmount.toStringAsFixed(0)} ₽',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, Color color) {
    return Column(
      children: [
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
        final date = DateTime.fromMillisecondsSinceEpoch(lesson['start_time']);
        final isPaid = lesson['is_paid'] == 1;

        return Card(
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isPaid ? Colors.green : Colors.red),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPaid ? Icons.check_circle_outline : Icons.highlight_off,
                color: isPaid ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              lesson['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(DateFormat.yMMMd('ru').format(date)),
            trailing: Text(
              '${(lesson['price'] as num).toStringAsFixed(0)} ₽',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      },
    );
  }
}
