import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/lesson.dart';
import 'package:rephelp/models/student.dart';
import 'package:rephelp/notification_service.dart';
import 'package:rephelp/widgets/custom_app_bar.dart';

class AddLessonScreen extends StatefulWidget {
  final List<Student> students;
  final DateTime selectedDate;
  final Lesson? lessonToEdit;

  const AddLessonScreen({
    super.key,
    required this.students,
    required this.selectedDate,
    this.lessonToEdit,
  });

  @override
  State<AddLessonScreen> createState() => _AddLessonScreenState();
}

class _AddLessonScreenState extends State<AddLessonScreen> {
  final _formKey = GlobalKey<FormState>();
  Student? _selectedStudent;
  late DateTime _lessonDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late TextEditingController _notesController;
  bool _isFormValid = false;
  int? _reminderTime;

  bool _duplicateLessons = false;
  DateTime? _duplicationStartDate;
  DateTime? _duplicationEndDate;
  bool _applyToFutureLessons = false;

  @override
  void initState() {
    super.initState();
    _lessonDate = widget.selectedDate;
    _notesController = TextEditingController();

    if (widget.lessonToEdit != null) {
      final lesson = widget.lessonToEdit!;
      _lessonDate = lesson.startTime;
      _startTime = TimeOfDay.fromDateTime(lesson.startTime);
      _endTime = TimeOfDay.fromDateTime(lesson.endTime);
      _notesController.text = lesson.notes ?? '';
      _reminderTime = lesson.reminderTime;
      try {
        _selectedStudent = widget.students.firstWhere(
          (s) => s.id == lesson.studentId,
        );
      } catch (e) {
        _selectedStudent = null;
      }
    } else if (widget.students.isNotEmpty) {
      _selectedStudent = widget.students.first;
    }
    _validateForm();
  }

  void _validateForm() {
    final isValid =
        _selectedStudent != null &&
        _startTime != null &&
        _endTime != null &&
        (_startTime!.hour < _endTime!.hour ||
            (_startTime!.hour == _endTime!.hour &&
                _startTime!.minute < _endTime!.minute));
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _saveLesson() async {
    if (!_formKey.currentState!.validate() || !_isFormValid) {
      return;
    }

    final student = _selectedStudent!;
    final startTime = _startTime!;
    final endTime = _endTime!;
    final database = AppDatabase();

    // Сценарий 1: Редактирование этого и всех будущих занятий
    if (_applyToFutureLessons && widget.lessonToEdit != null) {
      await _updateFutureLessons(database, student, startTime, endTime);
    }
    // Сценарий 2: Создание повторяющихся занятий (дублирование)
    else if (_duplicateLessons &&
        _duplicationStartDate != null &&
        _duplicationEndDate != null) {
      await _createRecurringLessons(database, student, startTime, endTime);
    }
    // Сценарий 3: Создание или обновление одного занятия
    else {
      await _saveSingleLesson(database, student, startTime, endTime);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  /// Сохраняет или обновляет одно занятие и его уведомление.
  Future<void> _saveSingleLesson(
    AppDatabase database,
    Student student,
    TimeOfDay startTime,
    TimeOfDay endTime,
  ) async {
    final lessonStartTime = DateTime(
      _lessonDate.year,
      _lessonDate.month,
      _lessonDate.day,
      startTime.hour,
      startTime.minute,
    );
    final lessonEndTime = DateTime(
      _lessonDate.year,
      _lessonDate.month,
      _lessonDate.day,
      endTime.hour,
      endTime.minute,
    );

    if (widget.lessonToEdit != null) {
      final lessonToUpdate = Lesson(
        id: widget.lessonToEdit!.id,
        studentId: student.id!,
        startTime: lessonStartTime,
        endTime: lessonEndTime,
        isPaid: widget.lessonToEdit!.isPaid,
        notes: _notesController.text,
        price: student.price,
        reminderTime: _reminderTime,
      );
      await database.updateLesson(lessonToUpdate);
      await _rescheduleNotification(lessonToUpdate, student);
    } else {
      final newLesson = Lesson(
        studentId: student.id!,
        startTime: lessonStartTime,
        endTime: lessonEndTime,
        notes: _notesController.text,
        price: student.price,
        reminderTime: _reminderTime,
      );
      final lessonId = await database.insertLesson(newLesson);
      // Важно! Создаем новый объект Lesson с полученным ID для планирования уведомления
      final lessonWithId = Lesson(
        id: lessonId,
        studentId: newLesson.studentId,
        startTime: newLesson.startTime,
        endTime: newLesson.endTime,
        notes: newLesson.notes,
        price: newLesson.price,
        reminderTime: newLesson.reminderTime,
      );
      await _rescheduleNotification(lessonWithId, student);
    }
  }

  /// Создает серию повторяющихся занятий и планирует уведомления для каждого.
  Future<void> _createRecurringLessons(
    AppDatabase database,
    Student student,
    TimeOfDay startTime,
    TimeOfDay endTime,
  ) async {
    final lessonsToSave = <Lesson>[];
    var currentDate = _duplicationStartDate!;
    while (!currentDate.isAfter(_duplicationEndDate!)) {
      if (currentDate.weekday == _lessonDate.weekday) {
        lessonsToSave.add(
          Lesson(
            studentId: student.id!,
            startTime: DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              startTime.hour,
              startTime.minute,
            ),
            endTime: DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              endTime.hour,
              endTime.minute,
            ),
            notes: _notesController.text,
            price: student.price,
            reminderTime: _reminderTime,
          ),
        );
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    if (widget.lessonToEdit != null) {
      // Отменяем старое уведомление перед удалением урока
      await NotificationService.cancelNotification(widget.lessonToEdit!.id!);
      await database.deleteLesson(widget.lessonToEdit!.id!);
    }

    if (lessonsToSave.isNotEmpty) {
      // Вставляем все уроки в БД и планируем уведомления
      for (final lesson in lessonsToSave) {
        final lessonId = await database.insertLesson(lesson);
        final lessonWithId = Lesson(
          id: lessonId,
          studentId: lesson.studentId,
          startTime: lesson.startTime,
          endTime: lesson.endTime,
          notes: lesson.notes,
          price: lesson.price,
          reminderTime: lesson.reminderTime,
        );
        await _rescheduleNotification(lessonWithId, student);
      }
    }
  }

  /// Обновляет будущие занятия
  Future<void> _updateFutureLessons(
    AppDatabase database,
    Student student,
    TimeOfDay startTime,
    TimeOfDay endTime,
  ) async {
    final originalLesson = widget.lessonToEdit!;
    final lessonsToUpdate = await database.getFutureRecurringLessons(
      originalLesson.studentId,
      originalLesson.startTime,
    );
    final dayDifference =
        _lessonDate.weekday - originalLesson.startTime.weekday;

    final updatedLessons = lessonsToUpdate.map((lesson) {
      final newDate = lesson.startTime.add(Duration(days: dayDifference));
      final newStartTime = DateTime(
        newDate.year,
        newDate.month,
        newDate.day,
        startTime.hour,
        startTime.minute,
      );
      final newEndTime = DateTime(
        newDate.year,
        newDate.month,
        newDate.day,
        endTime.hour,
        endTime.minute,
      );

      return Lesson(
        id: lesson.id,
        studentId: lesson.studentId,
        startTime: newStartTime,
        endTime: newEndTime,
        isPaid: lesson.isPaid,
        notes: _notesController.text,
        price: student.price,
        reminderTime: _reminderTime,
      );
    }).toList();

    if (updatedLessons.isNotEmpty) {
      await database.updateLessons(updatedLessons);
      // Перепланируем уведомления для всех обновленных уроков
      for (final lesson in updatedLessons) {
        await _rescheduleNotification(lesson, student);
      }
    }
  }

  /// Вспомогательный метод для планирования или отмены уведомления
  Future<void> _rescheduleNotification(Lesson lesson, Student student) async {
    if (lesson.id == null) return;

    if (_reminderTime != null && _reminderTime! > 0) {
      await NotificationService.scheduleLessonNotification(
        lessonId: lesson.id!,
        studentName: '${student.name} ${student.surname ?? ''}',
        lessonTime: lesson.startTime,
        reminderMinutes: _reminderTime!,
      );
    } else {
      await NotificationService.cancelNotification(lesson.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(
          widget.lessonToEdit != null
              ? 'Редактировать занятие'
              : 'Добавить занятие',
          style: const TextStyle(fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                Icons.check_circle_outline,
                color: _isFormValid ? Colors.white : Colors.white54,
                size: 30,
              ),
              onPressed: _isFormValid ? _saveLesson : null,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(10.0),
          children: [
            _buildSectionTitle('Время и дата'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.deepPurple,
                    ),
                    title: const Text('Дата'),
                    trailing: Text(
                      DateFormat('dd.MM.yy').format(_lessonDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: _selectLessonDate,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.access_time,
                      color: Colors.deepPurple,
                    ),
                    title: const Text('Начало'),
                    trailing: Text(
                      _startTime?.format(context) ?? 'Выберите время',
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () => _selectTime(true),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.access_time_filled,
                      color: Colors.deepPurple,
                    ),
                    title: const Text('Конец'),
                    trailing: Text(
                      _endTime?.format(context) ?? 'Выберите время',
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () => _selectTime(false),
                  ),
                ],
              ),
            ),
            _buildSectionTitle('Напоминание'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: DropdownButtonFormField<int>(
                  value: _reminderTime,
                  onChanged: (int? newValue) {
                    setState(() {
                      _reminderTime = newValue;
                    });
                  },
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Нет'),
                    ),
                    const DropdownMenuItem<int>(
                      value: 5,
                      child: Text('За 5 минут'),
                    ),
                    const DropdownMenuItem<int>(
                      value: 10,
                      child: Text('За 10 минут'),
                    ),
                    const DropdownMenuItem<int>(
                      value: 15,
                      child: Text('За 15 минут'),
                    ),
                    const DropdownMenuItem<int>(
                      value: 30,
                      child: Text('За 30 минут'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Выберите время напоминания',
                  ),
                  isExpanded: true,
                ),
              ),
            ),
            _buildSectionTitle('Ученик'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: DropdownButtonFormField<Student>(
                  value: _selectedStudent,
                  onChanged: (Student? newValue) {
                    setState(() {
                      _selectedStudent = newValue;
                    });
                    _validateForm();
                  },
                  items: widget.students.map<DropdownMenuItem<Student>>((
                    Student student,
                  ) {
                    return DropdownMenuItem<Student>(
                      value: student,
                      child: Text('${student.name} ${student.surname ?? ''}'),
                    );
                  }).toList(),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Выберите ученика',
                  ),
                  isExpanded: true,
                  validator: (value) =>
                      value == null ? 'Пожалуйста, выберите ученика' : null,
                ),
              ),
            ),
            if (widget.lessonToEdit == null) ...[
              _buildSectionTitle('Дублирование'),
              Card(
                color: Colors.white,
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text(
                        'Продублировать занятия в указанный день недели',
                      ),
                      value: _duplicateLessons,
                      onChanged: (bool? value) {
                        setState(() {
                          _duplicateLessons = value ?? false;
                        });
                        _validateForm();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.deepPurple,
                    ),
                    if (_duplicateLessons) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(
                          Icons.calendar_today,
                          color: Colors.deepPurple,
                        ),
                        title: const Text('С'),
                        trailing: Text(
                          _duplicationStartDate == null
                              ? 'Выберите дату'
                              : DateFormat(
                                  'dd.MM.yy',
                                ).format(_duplicationStartDate!),
                        ),
                        onTap: () => _selectDuplicationDate(true),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(
                          Icons.calendar_today,
                          color: Colors.deepPurple,
                        ),
                        title: const Text('По'),
                        trailing: Text(
                          _duplicationEndDate == null
                              ? 'Выберите дату'
                              : DateFormat(
                                  'dd.MM.yy',
                                ).format(_duplicationEndDate!),
                        ),
                        onTap: () => _selectDuplicationDate(false),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (widget.lessonToEdit != null) ...[
              _buildSectionTitle('Массовое редактирование'),
              Card(
                color: Colors.white,
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text(
                        'Применить к этому и всем последующим занятиям',
                      ),
                      value: _applyToFutureLessons,
                      onChanged: (bool? value) {
                        setState(() {
                          _applyToFutureLessons = value ?? false;
                        });
                        _validateForm();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.deepPurple,
                    ),
                  ],
                ),
              ),
            ],
            _buildSectionTitle('Примечания'),
            Column(
              children: [
                Card(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText: 'Добавьте примечание к занятию...',
                        border: InputBorder.none,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 50.0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.deepPurple,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Future<void> _selectLessonDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lessonDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('ru'),
    );
    if (picked != null && picked != _lessonDate) {
      setState(() {
        _lessonDate = picked;
      });
      _validateForm();
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final initialTime = isStartTime
        ? _startTime
        : _endTime ?? _startTime ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
      _validateForm();
    }
  }

  Future<void> _selectDuplicationDate(bool isStart) async {
    final initialDate =
        (isStart ? _duplicationStartDate : _duplicationEndDate) ?? _lessonDate;
    final firstDate = isStart
        ? _lessonDate
        : _duplicationStartDate ?? _lessonDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2101),
      locale: const Locale('ru'),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _duplicationStartDate = picked;
          if (_duplicationEndDate != null &&
              _duplicationEndDate!.isBefore(picked)) {
            _duplicationEndDate = null;
          }
        } else {
          _duplicationEndDate = picked;
        }
      });
      _validateForm();
    }
  }
}