import 'package:flutter/material.dart';
import 'package:rephelp/widgets/custom_app_bar.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/lesson.dart';
import 'package:rephelp/models/student.dart';
import 'package:rephelp/screens/add_lesson_screen.dart';
import 'package:rephelp/utils/app_colors.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final AppDatabase _database = AppDatabase();
  List<Map<String, dynamic>> _lessons = [];
  List<Student> _students = [];
  Map<DateTime, List<Lesson>> _allLessons = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final allStudents = await _database.getStudents();
    final allLessons = await _database.getAllLessons();
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
      appBar: CustomAppBar(title: 'Расписание', backgroundColor: AppColors.lavender),
      body: Column(
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
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            eventLoader: (day) {
              final isSelected = isSameDay(_selectedDay, day);
              if (isSelected) {
                return [];
              }
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
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.warning, color: Colors.orange),
                        // Добавляем onTap для редактирования
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddLessonScreen(
                                students: _students,
                                selectedDate: _selectedDay!,
                                lessonToEdit:
                                    lesson, // Передаем объект занятия для редактирования
                              ),
                            ),
                          );
                          if (result == true) {
                            await _loadAllData();
                            await _loadLessonsForDay(_selectedDay!);
                          }
                        },
                        onLongPress: () {
                          // Вызываем диалог подтверждения
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Удалить занятие?'),
                                content: const Text(
                                  'Вы уверены, что хотите удалить это занятие? '
                                  'Это действие необратимо.',
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Отмена'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      // Удаляем занятие из базы данных
                                      await _database.deleteLesson(lesson.id!);

                                      // Обновляем состояние, удаляя занятие из списков в памяти
                                      setState(() {
                                        // 1. Удаляем занятие из списка на текущий день
                                        _lessons.removeWhere(
                                          (element) =>
                                              element['lesson'].id == lesson.id,
                                        );
                                        // 2. Удаляем занятие из списка всех занятий (для маркеров в календаре)
                                        final dayKey = DateTime(
                                          lesson.date.year,
                                          lesson.date.month,
                                          lesson.date.day,
                                        );
                                        if (_allLessons[dayKey] != null) {
                                          _allLessons[dayKey]!.removeWhere(
                                            (element) =>
                                                element.id == lesson.id,
                                          );
                                          // Если на дату больше нет занятий, удаляем ключ из карты
                                          if (_allLessons[dayKey]!.isEmpty) {
                                            _allLessons.remove(dayKey);
                                          }
                                        }
                                      });

                                      Navigator.pop(
                                        context,
                                      ); // Закрываем диалог
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
            await _loadLessonsForDay(_selectedDay!);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
