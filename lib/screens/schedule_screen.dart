import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rephelp/widgets/custom_app_bar.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/lesson.dart';
import 'package:rephelp/models/student.dart';
import 'package:rephelp/screens/add_lesson_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final AppDatabase _database = AppDatabase();
  List<Map<String, dynamic>> _lessons = [];
  List<Student> _students = [];
  Map<DateTime, List<Lesson>> _allLessons = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDay = _focusedDay;
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final allStudents = await _database.getStudents();
    final allLessons = await _database.getAllLessons();
    if (!mounted) return;
    await _loadLessonsForDay(_selectedDay!);
    setState(() {
      _students = allStudents;
      _allLessons = _groupLessonsByDate(allLessons);
    });
  }

  Future<void> _loadLessonsForDay(DateTime day) async {
    final lessons = await _database.getLessonsByDate(day);
    final List<Map<String, dynamic>> lessonsWithStudents = [];
    for (var lesson in lessons) {
      final student = _students.firstWhere((s) => s.id == lesson.studentId);
      lessonsWithStudents.add({'lesson': lesson, 'student': student});
    }
    if (!mounted) return;
    setState(() {
      _lessons = lessonsWithStudents;
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _loadLessonsForDay(selectedDay);
    }
  }

  Map<DateTime, List<Lesson>> _groupLessonsByDate(List<Lesson> lessons) {
    final Map<DateTime, List<Lesson>> data = {};
    for (var lesson in lessons) {
      final day = DateTime(
        lesson.date.year,
        lesson.date.month,
        lesson.date.day,
      );
      if (data.containsKey(day)) {
        data[day]!.add(lesson);
      } else {
        data[day] = [lesson];
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Расписание'),
      body: Column(
        children: [
          Container(
            color: Colors.deepPurple,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'Список'),
                Tab(text: 'Таблица'),
                Tab(text: 'Календарь'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListView(),
                _buildTableView(),
                _buildCalendarView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddLessonScreen(
                students: _students,
                selectedDate: _selectedDay!,
              ),
            ),
          );
          if (result == true) {
            await _loadAllData();
          }
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildListView() {
    if (_allLessons.isEmpty) {
      return const Center(child: Text('Нет запланированных занятий.'));
    }

    final sortedDays = _allLessons.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final lessons = _allLessons[day]!;
        final formattedDate = DateFormat(
          'dd.MM.yyyy, EEEE',
          'ru_RU',
        ).format(day);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                formattedDate,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ...lessons.map((lesson) {
              final student = _students.firstWhere(
                (s) => s.id == lesson.studentId,
              );
              return _buildLessonCard(lesson, student);
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildLessonCard(Lesson lesson, Student student) {
    final startTime = DateFormat('HH:mm').format(lesson.date);
    final endTime = DateFormat(
      'HH:mm',
    ).format(lesson.date.add(const Duration(hours: 1)));
    final studentName = '${student.name} ${student.surname?[0] ?? ''}.';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        title: Text('$startTime - $endTime'),
        subtitle: Text(studentName),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showLessonMenu(context, lesson, student),
        ),
      ),
    );
  }

  void _showLessonMenu(BuildContext context, Lesson lesson, Student student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Center(
            child: Column(
              children: [
                const Icon(Icons.person, size: 40),
                const SizedBox(height: 10),
                Text('${student.name} ${student.surname ?? ''}'),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Ученик отсутствовал'),
                onTap: () {
                  // TODO: Implement absence logic
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text('Занятие оплачено'),
                onTap: () {
                  // TODO: Implement payment logic
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text('Отмена'),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableView() {
    return const Center(child: Text('Таблица (в разработке)'));
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        TableCalendar(
          focusedDay: _focusedDay,
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: _onDaySelected,
          locale: 'ru_RU',
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.blueGrey,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.deepPurple,
              shape: BoxShape.circle,
            ),
          ),
          eventLoader: (day) {
            return _allLessons[DateTime(day.year, day.month, day.day)] ?? [];
          },
        ),
        const Divider(),
        Expanded(
          child: _lessons.isEmpty
              ? const Center(child: Text('На этот день занятий нет.'))
              : ListView.builder(
                  itemCount: _lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = _lessons[index]['lesson'] as Lesson;
                    final student = _lessons[index]['student'] as Student;
                    return ListTile(
                      title: Text('Занятие с ${student.name}'),
                      subtitle: Text('Цена: ${student.price} руб.'),
                      trailing: lesson.isPaid
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.warning, color: Colors.orange),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddLessonScreen(
                              students: _students,
                              selectedDate: _selectedDay!,
                              lessonToEdit: lesson,
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadAllData();
                        }
                      },
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Удалить занятие?'),
                              content: const Text(
                                'Вы уверены, что хотите удалить это занятие?',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Отмена'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await _database.deleteLesson(lesson.id!);
                                    await _loadAllData();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Удалить'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
