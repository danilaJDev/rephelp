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
  Map<DateTime, List<Map<String, dynamic>>> _allLessons = {};

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
      _allLessons = _groupAndPairLessons(allLessons, allStudents);
    });
  }

  Future<void> _loadLessonsForDay(DateTime day) async {
    final lessons = await _database.getLessonsByDate(day);
    final List<Map<String, dynamic>> lessonsWithStudents = [];
    for (var lesson in lessons) {
      try {
        final student = _students.firstWhere((s) => s.id == lesson.studentId);
        lessonsWithStudents.add({'lesson': lesson, 'student': student});
      } catch (e) {
        // Student not found for this lesson, maybe log this error
        print(
          'Error: Student with id ${lesson.studentId} not found for lesson ${lesson.id}',
        );
      }
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

  Map<DateTime, List<Map<String, dynamic>>> _groupAndPairLessons(
    List<Lesson> lessons,
    List<Student> students,
  ) {
    final Map<DateTime, List<Map<String, dynamic>>> data = {};
    for (var lesson in lessons) {
      try {
        final student = students.firstWhere((s) => s.id == lesson.studentId);
        final day = DateTime(
          lesson.startTime.year,
          lesson.startTime.month,
          lesson.startTime.day,
        );
        final lessonWithStudent = {'lesson': lesson, 'student': student};
        if (data.containsKey(day)) {
          data[day]!.add(lessonWithStudent);
        } else {
          data[day] = [lessonWithStudent];
        }
      } catch (e) {
        print('Student not found for lesson ${lesson.id}');
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
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
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
            ...lessons.map((lessonData) {
              final lesson = lessonData['lesson'] as Lesson;
              final student = lessonData['student'] as Student;
              return _buildLessonCard(lesson, student);
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildLessonCard(Lesson lesson, Student student) {
    final startTime = DateFormat('HH:mm').format(lesson.startTime);
    final endTime = DateFormat('HH:mm').format(lesson.endTime);
    final studentName = '${student.name} ${student.surname ?? ''}';

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
                title: const Text('Отменить занятие', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(context).pop(); // Close the menu dialog
                  _showCancelOptionsDialog(lesson, student);
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Закрыть'),
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

  void _showCancelOptionsDialog(Lesson lesson, Student student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Отменить занятие'),
          content: const Text('Как вы хотите отменить занятие?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Только это'),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the options dialog
                await _database.deleteLesson(lesson.id!);
                await _loadAllData();
              },
            ),
            TextButton(
              child: const Text('Это и все последующие'),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the options dialog
                await _database.deleteFutureRecurringLessons(
                  student.id!,
                  lesson.startTime,
                );
                await _loadAllData();
              },
            ),
            TextButton(
              child: const Text('Закрыть', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
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
                              selectedDate: lesson.startTime,
                              lessonToEdit: lesson,
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadAllData();
                        }
                      },
                      onLongPress: () => _showCancelOptionsDialog(lesson, student),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
