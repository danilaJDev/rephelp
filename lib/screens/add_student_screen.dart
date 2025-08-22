import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/student.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:rephelp/models/lesson.dart';

class AddStudentScreen extends StatefulWidget {
  final Student? student;

  const AddStudentScreen({super.key, this.student});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  // Контроллеры для получения текста из полей ввода
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Ключ для валидации формы
  final _formKey = GlobalKey<FormState>();

  final List<String> _weekdays = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  String _selectedDay = 'Понедельник';
  TimeOfDay _selectedTime = TimeOfDay.now();
  List<Map<String, dynamic>> _schedule = [];

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _nameController.text = widget.student!.name;
      _contactController.text = widget.student!.contact;
      _priceController.text = widget.student!.price.toString();
      _notesController.text = widget.student!.notes;
      _schedule = (jsonDecode(widget.student!.schedule) as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addScheduleEntry() {
    setState(() {
      _schedule.add({
        'day': _selectedDay,
        'time':
            '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
      });
    });
  }

  void _removeScheduleEntry(int index) {
    setState(() {
      _schedule.removeAt(index);
    });
  }

  // Метод для сохранения нового ученика в базу данных
  Future<void> _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      final newStudent = Student(
        id: widget.student?.id,
        name: _nameController.text,
        contact: _contactController.text,
        price: double.parse(_priceController.text),
        notes: _notesController.text,
        schedule: jsonEncode(_schedule),
      );

      final database = AppDatabase();
      if (newStudent.id != null) {
        await database.updateStudent(newStudent);
      } else {
        await database.insertStudent(newStudent);
        if (_schedule.isNotEmpty) {
          await _createInitialLessons(newStudent.id!, _schedule);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _createInitialLessons(
    int studentId,
    List<Map<String, dynamic>> schedule,
  ) async {
    final now = DateTime.now();
    final lessonsToCreate = <Lesson>[];

    // Генерируем занятия на ближайшие 8 недель
    for (var i = 0; i < 8; i++) {
      for (var entry in schedule) {
        final day = _weekdays.indexOf(entry['day'] as String) + 1;
        final timeParts = (entry['time'] as String).split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        final nextLessonDate = _findNextWeekday(now, day, hour, minute);
        lessonsToCreate.add(
          Lesson(studentId: studentId, date: nextLessonDate, isPaid: false),
        );
      }
    }
    await AppDatabase().insertLessons(lessonsToCreate);
  }

  DateTime _findNextWeekday(DateTime start, int weekday, int hour, int minute) {
    var date = start.add(Duration(days: 1));
    while (date.weekday != weekday) {
      date = date.add(Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.student == null ? 'Добавить ученика' : 'Редактировать ученика',
        ),
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Имя'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите имя';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Контакты'),
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Цена за занятие (руб)',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите цену';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Пожалуйста, введите число';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Заметки'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              const Text(
                'Расписание занятий',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (_schedule.isNotEmpty)
                ..._schedule.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return ListTile(
                    title: Text('${item['day']} в ${item['time']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeScheduleEntry(index),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'День недели',
                      ),
                      value: _selectedDay,
                      items: _weekdays.map((day) {
                        return DropdownMenuItem<String>(
                          value: day,
                          child: Text(day),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDay = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (pickedTime != null) {
                          setState(() {
                            _selectedTime = pickedTime;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Время',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_selectedTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _addScheduleEntry,
                icon: const Icon(Icons.add),
                label: const Text('Добавить занятие'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveStudent,
                child: Text(widget.student == null ? 'Создать' : 'Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
