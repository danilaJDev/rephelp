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
  DateTime _focusedDateForTable = DateTime.now();

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
    setState(() {
      _students = allStudents;
      _allLessons = _groupAndPairLessons(allLessons, allStudents);
    });
    await _loadLessonsForDay(_selectedDay!);
  }

  Future<void> _loadLessonsForDay(DateTime day) async {
    final lessons = await _database.getLessonsByDate(day);
    final List<Map<String, dynamic>> lessonsWithStudents = [];
    for (var lesson in lessons) {
      try {
        final student = _students.firstWhere((s) => s.id == lesson.studentId);
        lessonsWithStudents.add({'lesson': lesson, 'student': student});
      } catch (e) {
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

  Future<void> _editLesson(Lesson lesson) async {
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
      appBar: CustomAppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Text('Расписание', style: TextStyle(fontSize: 24)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddLessonScreen(
                      students: _students,
                      selectedDate: _selectedDay ?? DateTime.now(),
                    ),
                  ),
                );
                if (result == true) {
                  await _loadAllData();
                }
              },
            ),
          ),
        ],
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
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,

              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 14),

              tabs: const [
                Tab(icon: Icon(Icons.list_alt), text: 'Список'),
                Tab(icon: Icon(Icons.table_chart), text: 'Таблица'),
                Tab(icon: Icon(Icons.calendar_month), text: 'Календарь'),
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
        lessons.sort(
          (a, b) => (a['lesson'] as Lesson).startTime.compareTo(
            (b['lesson'] as Lesson).startTime,
          ),
        );
        final formattedDate = DateFormat(
          'dd.MM.yyyy, EEEE',
          'ru_RU',
        ).format(day);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 15, 8, 8),
              child: Text(
                formattedDate,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
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
    final hasNotes = lesson.notes != null && lesson.notes!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: () => _editLesson(lesson),
        title: Text(
          '$startTime - $endTime',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              studentName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (hasNotes) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.sticky_note_2_outlined,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lesson.notes!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Редактировать'),
                onTap: () {
                  Navigator.of(context).pop();
                  _editLesson(lesson);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Отменить занятие',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showCancelOptionsDialog(lesson, student);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Закрыть'),
                onTap: () => Navigator.of(context).pop(),
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
                Navigator.of(context).pop();
                await _database.deleteLesson(lesson.id!);
                await _loadAllData();
              },
            ),
            TextButton(
              child: const Text('Это и все последующие'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _database.deleteFutureRecurringLessons(
                  student.id!,
                  lesson.startTime,
                );
                await _loadAllData();
              },
            ),
            TextButton(
              child: const Text(
                'Закрыть',
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  TableRow _buildHeaderRow(List<DateTime> daysOfWeek) {
    final format = DateFormat('E, d', 'ru_RU');
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey[200]),
      children: [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Время', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        ...daysOfWeek.map(
          (day) => Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                format.format(day),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getLessonsForSlot(
    DateTime day,
    TimeOfDay time,
    Map<DateTime, List<Map<String, dynamic>>> weekLessons,
  ) {
    final dayKey = DateTime(day.year, day.month, day.day);
    if (!weekLessons.containsKey(dayKey)) {
      return [];
    }
    final lessonsForDay = weekLessons[dayKey]!;
    final lessonsInSlot = lessonsForDay.where((lessonData) {
      final lesson = lessonData['lesson'] as Lesson;
      final lessonTime = TimeOfDay.fromDateTime(lesson.startTime);
      return lessonTime.hour == time.hour;
    }).toList();

    lessonsInSlot.sort(
      (a, b) => (a['lesson'] as Lesson).startTime.compareTo(
        (b['lesson'] as Lesson).startTime,
      ),
    );

    return lessonsInSlot;
  }

  TableRow _buildTimeSlotRow(
    TimeOfDay time,
    List<DateTime> daysOfWeek,
    Map<DateTime, List<Map<String, dynamic>>> weekLessons,
  ) {
    return TableRow(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            ),
          ),
        ),
        ...daysOfWeek.map((day) {
          final lessonsInSlot = _getLessonsForSlot(day, time, weekLessons);
          if (lessonsInSlot.isEmpty) {
            return DragTarget<Lesson>(
              builder: (context, candidateData, rejectedData) {
                return Container(height: 60);
              },
              onWillAccept: (data) => true,
              onAccept: (data) {},
            );
          }
          return Container(
            padding: const EdgeInsets.all(2.0),
            child: Column(
              children: lessonsInSlot.map((lessonData) {
                final lesson = lessonData['lesson'] as Lesson;
                final student = lessonData['student'] as Student;
                final startTime = DateFormat('HH:mm').format(lesson.startTime);
                final endTime = DateFormat('HH:mm').format(lesson.endTime);
                final timeRange = '$startTime-$endTime';

                // Format student name
                String studentDisplayName = student.name;
                if (student.surname != null && student.surname!.isNotEmpty) {
                  studentDisplayName += ' ${student.surname![0]}.';
                }

                final lessonWidget = Card(
                  elevation: 2,
                  color: Colors.deepPurple,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          studentDisplayName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeRange,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );

                return Draggable<Lesson>(
                  data: lesson,
                  feedback: Opacity(opacity: 0.7, child: lessonWidget),
                  childWhenDragging: Opacity(opacity: 0.3, child: lessonWidget),
                  child: GestureDetector(
                    onTap: () => _showLessonMenu(context, lesson, student),
                    child: lessonWidget,
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTableNavigator() {
    final startDate = _focusedDateForTable;
    final endDate = startDate.add(const Duration(days: 2));
    final format = DateFormat('d MMM', 'ru_RU');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedDateForTable = _focusedDateForTable.subtract(
                  const Duration(days: 3),
                );
              });
            },
          ),
          Text(
            '${format.format(startDate)} - ${format.format(endDate)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedDateForTable = _focusedDateForTable.add(
                  const Duration(days: 3),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableView() {
    final daysToDisplay = List.generate(
      3,
      (index) => _focusedDateForTable.add(Duration(days: index)),
    );
    final timeSlots = List.generate(
      15,
      (index) => TimeOfDay(hour: 8 + index, minute: 0),
    );

    final displayedDays = daysToDisplay
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    final viewLessons = <DateTime, List<Map<String, dynamic>>>{};
    _allLessons.forEach((day, lessons) {
      if (displayedDays.contains(day)) {
        viewLessons[day] = lessons;
      }
    });

    return Column(
      children: [
        _buildTableNavigator(),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == 0) return;
              if (details.primaryVelocity! > 0) {
                setState(() {
                  _focusedDateForTable = _focusedDateForTable.subtract(
                    const Duration(days: 3),
                  );
                });
              } else {
                setState(() {
                  _focusedDateForTable = _focusedDateForTable.add(
                    const Duration(days: 3),
                  );
                });
              }
            },
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {
                  0: IntrinsicColumnWidth(),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                  3: FlexColumnWidth(),
                },
                children: [
                  _buildHeaderRow(daysToDisplay),
                  ...timeSlots.map(
                    (time) =>
                        _buildTimeSlotRow(time, daysToDisplay, viewLessons),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
            final key = DateTime(day.year, day.month, day.day);
            return _allLessons[key] ?? [];
          },

          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return const SizedBox();

              if (isSameDay(day, _selectedDay)) {
                return const SizedBox();
              }

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final currentDay = DateTime(day.year, day.month, day.day);

              final isPast = currentDay.isBefore(today);
              final dotColor = isPast ? Colors.black87 : Colors.red;

              return Positioned(
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
              );
            },
          ),
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
                    return _buildLessonCard(lesson, student);
                  },
                ),
        ),
      ],
    );
  }
}
