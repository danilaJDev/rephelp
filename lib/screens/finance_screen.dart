import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:intl/intl.dart';
import 'package:rephelp/screens/income_statistics_screen.dart';
import 'package:rephelp/widgets/custom_app_bar.dart';
import 'package:rephelp/widgets/student_selection_dialog.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _AnimatedFinanceDialog extends StatefulWidget {
  final String initialViewMode;
  final ValueChanged<String> onViewModeChanged;

  const _AnimatedFinanceDialog({
    required this.initialViewMode,
    required this.onViewModeChanged,
  });

  @override
  _AnimatedFinanceDialogState createState() => _AnimatedFinanceDialogState();
}

class _AnimatedFinanceDialogState extends State<_AnimatedFinanceDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late String _tempViewMode;

  @override
  void initState() {
    super.initState();
    _tempViewMode = widget.initialViewMode;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closeDialog() {
    _controller.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          title: const Center(
            child: Text(
              'Вид экрана',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          content: Theme(
            data: Theme.of(
              context,
            ).copyWith(unselectedWidgetColor: Colors.deepPurple),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Только оплаченные'),
                  value: 'paid',
                  groupValue: _tempViewMode,
                  onChanged: (String? value) {
                    setState(() {
                      _tempViewMode = value!;
                    });
                    widget.onViewModeChanged(_tempViewMode);
                    _closeDialog();
                  },
                  activeColor: Colors.deepPurple,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: const Text('Только неоплаченные'),
                  value: 'unpaid',
                  groupValue: _tempViewMode,
                  onChanged: (String? value) {
                    setState(() {
                      _tempViewMode = value!;
                    });
                    widget.onViewModeChanged(_tempViewMode);
                    _closeDialog();
                  },
                  activeColor: Colors.deepPurple,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            if (_tempViewMode != 'all')
              TextButton(
                onPressed: () {
                  widget.onViewModeChanged('all');
                  _closeDialog();
                },
                child: const Text(
                  'Сбросить',
                  style: TextStyle(color: Colors.deepPurple),
                ),
              ),
            TextButton(
              onPressed: _closeDialog,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.deepPurple),
                foregroundColor: Colors.deepPurple,
              ),
              child: const Text('Отмена'),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        ),
      ),
    );
  }
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.payment), text: 'Занятия'),
                Tab(icon: Icon(Icons.bar_chart), text: 'Статистика'),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [ClassesView(), IncomeStatisticsScreen()],
            ),
          ),
        ],
      ),
    );
  }
}

class ClassesView extends StatefulWidget {
  const ClassesView({super.key});

  @override
  State<ClassesView> createState() => _ClassesViewState();
}

class _ClassesViewState extends State<ClassesView> {
  final AppDatabase _database = AppDatabase();
  Map<String, List<Map<String, dynamic>>> _groupedFinancialData = {};

  bool _isLoading = true;
  List<int>? _selectedStudentIds;
  String _viewMode = 'all';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _initializeStudentFilter();
  }

  Future<void> _initializeStudentFilter() async {
    final students = await _database.getStudents(isArchived: false);
    if (!mounted) return;
    setState(() {
      _selectedStudentIds = students.map((s) => s.id!).toList();
    });
    await _loadFinancialData();
  }

  Future<void> _loadFinancialData({bool withSpinner = true}) async {
    if (withSpinner) {
      if (!mounted) return;
      setState(() => _isLoading = true);
    }

    if (_selectedStudentIds == null) {
      if (withSpinner) {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
      return;
    }

    if (_selectedStudentIds!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _groupedFinancialData = {};

        _isLoading = false;
      });
      return;
    }

    var allLessons = await _database.getFinancialData(
      studentIds: _selectedStudentIds,
    );
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

    Map<String, List<Map<String, dynamic>>> groupedData = {};

    for (var lesson in allLessons) {
      final studentName = '${lesson['name']} ${lesson['surname'] ?? ''}';
      groupedData.putIfAbsent(studentName, () => []).add(lesson);
    }

    if (!mounted) return;
    setState(() {
      _groupedFinancialData = groupedData;

      if (withSpinner) _isLoading = false;
    });
  }

  Future<void> _toggleLessonPaidStatus(int lessonId, bool isPaid) async {
    await _database.updateLessonIsPaid(lessonId, !isPaid);

    await _loadFinancialData(withSpinner: false);
  }

  void _showViewAgendaDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _AnimatedFinanceDialog(
          initialViewMode: _viewMode,
          onViewModeChanged: (String newViewMode) {
            setState(() {
              _viewMode = newViewMode;
            });
            _loadFinancialData();
          },
        );
      },
    );
  }

  Future<void> _showCalendarDialog() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'ВЫБЕРИТЕ ДАТУ',
      cancelText: 'ОТМЕНА',
      confirmText: 'ВЫБРАТЬ',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              headerHeadlineStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              cancelButtonStyle: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                side: const BorderSide(color: Colors.grey),
              ),
              confirmButtonStyle: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                minimumSize: const Size(100, 30),
                alignment: Alignment.center,
              ),
            ),
          ),
          child: Center(child: child),
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        _selectedDate = selectedDate;
      });
      await _loadFinancialData();
    } else if (_selectedDate != null) {
      setState(() {
        _selectedDate = null;
      });
      await _loadFinancialData();
    }
  }

  Future<void> _openStudentSelectionDialog() async {
    if (_selectedStudentIds == null) return;

    final selectedIds = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        return StudentSelectionDialog(initialSelectedIds: _selectedStudentIds!);
      },
    );

    if (selectedIds != null) {
      setState(() {
        _selectedStudentIds = selectedIds;
      });
      await _loadFinancialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => _loadFinancialData(withSpinner: false),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildFinancialList()),
              ],
            ),
          );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 15),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _openStudentSelectionDialog,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                alignment: Alignment.centerLeft,
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Все ученики',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.black,
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _showViewAgendaDialog,
              icon: const Icon(Icons.view_agenda_outlined),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _showCalendarDialog,
              icon: const Icon(Icons.calendar_today_outlined),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialList() {
    if (_groupedFinancialData.isEmpty) {
      return const Center(
        child: Text(
          'Занятий пока нет',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    Map<String, List<Map<String, dynamic>>> filteredData = {};

    _groupedFinancialData.forEach((studentName, lessons) {
      final filteredLessons = lessons.where((lesson) {
        final isPaid = lesson['is_paid'] == 1;
        final lessonDate = DateTime.fromMillisecondsSinceEpoch(
          lesson['start_time'],
        );

        bool viewModeFilter = true;
        if (_viewMode == 'paid') {
          viewModeFilter = isPaid;
        } else if (_viewMode == 'unpaid') {
          viewModeFilter = !isPaid;
        }

        bool dateFilter = true;
        if (_selectedDate != null) {
          dateFilter =
              lessonDate.year == _selectedDate!.year &&
              lessonDate.month == _selectedDate!.month &&
              lessonDate.day == _selectedDate!.day;
        }

        return viewModeFilter && dateFilter;
      }).toList();

      if (filteredLessons.isNotEmpty) {
        filteredData[studentName] = filteredLessons;
      }
    });

    if (filteredData.isEmpty) {
      return const Center(
        child: Text(
          'Нет занятий, соответствующих фильтрам',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final studentNames = filteredData.keys.toList();

    return ListView.builder(
      itemCount: studentNames.length,
      itemBuilder: (context, index) {
        final studentName = studentNames[index];
        final lessons = filteredData[studentName]!;

        lessons.sort(
          (a, b) => (a['start_time'] as int).compareTo(b['start_time'] as int),
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            key: PageStorageKey<String>('finance_$studentName'),
            maintainState: true,
            title: Text(
              studentName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.deepPurple,
              ),
            ),
            children: lessons.map((lesson) {
              final startTime = DateTime.fromMillisecondsSinceEpoch(
                lesson['start_time'],
              );
              final endTime = DateTime.fromMillisecondsSinceEpoch(
                lesson['end_time'],
              );
              final isPaid = lesson['is_paid'] == 1;
              final isFuture = DateTime.now().isBefore(endTime);

              final lessonDate = DateFormat.yMMMd('ru').format(startTime);
              final lessonTime =
                  '${DateFormat.Hm('ru').format(startTime)} - ${DateFormat.Hm('ru').format(endTime)}';
              final price = (lesson['price'] as num).toStringAsFixed(0);

              String statusText;
              String titleStatusText;
              Color statusColor;
              Color priceColor;
              Color tileColor;
              IconData icon;
              Color iconBackgroundColor;
              Color titleStatusColor;
              Color iconColor;

              if (isFuture) {
                titleStatusText = 'Запланировано';
                titleStatusColor = Colors.grey;
                if (isPaid) {
                  statusText = 'Оплачено';
                  statusColor = Colors.green;
                  priceColor = Colors.green;
                  tileColor = Colors.grey[200]!;
                  icon = Icons.watch_later;
                  iconBackgroundColor = Colors.grey[300]!;
                  iconColor = Colors.grey;
                } else {
                  statusText = 'Не оплачен';
                  statusColor = Colors.grey;
                  priceColor = Colors.grey;
                  tileColor = Colors.grey[200]!;
                  icon = Icons.watch_later;
                  iconBackgroundColor = Colors.grey[300]!;
                  iconColor = Colors.grey;
                }
              } else {
                titleStatusText = 'Состоялось';
                if (isPaid) {
                  statusText = 'Оплачено';
                  statusColor = Colors.green;
                  priceColor = Colors.green;
                  tileColor = Colors.green[50]!;
                  icon = Icons.check_circle;
                  iconBackgroundColor = Colors.green[100]!;
                  titleStatusColor = Colors.green;
                  iconColor = Colors.green;
                } else {
                  statusText = 'Ожидает оплаты';
                  statusColor = Colors.orange;
                  priceColor = Colors.orange;
                  tileColor = Colors.orange[50]!;
                  icon = Icons.hourglass_bottom;
                  iconBackgroundColor = Colors.orange[100]!;
                  titleStatusColor = Colors.orange;
                  iconColor = Colors.orange;
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 5,
                  horizontal: 10,
                ),
                child: Material(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(10),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: iconBackgroundColor,
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lessonDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(lessonTime, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleStatusText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: titleStatusColor,
                          ),
                        ),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '$price руб.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: priceColor,
                      ),
                    ),
                    onTap: () =>
                        _toggleLessonPaidStatus(lesson['id'] as int, isPaid),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
