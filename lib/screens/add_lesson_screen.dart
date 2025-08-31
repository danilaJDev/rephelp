import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/lesson.dart';
import 'package:rephelp/models/student.dart';
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
  late TextEditingController _priceController;
  bool _isFormValid = false;

  bool _duplicateLessons = false;
  DateTime? _duplicationStartDate;
  DateTime? _duplicationEndDate;
  bool _applyToFutureLessons = false;

  @override
  void initState() {
    super.initState();
    _lessonDate = widget.selectedDate;
    _notesController = TextEditingController();
    _priceController = TextEditingController();

    if (widget.lessonToEdit != null) {
      final lesson = widget.lessonToEdit!;
      _lessonDate = lesson.startTime;
      _startTime = TimeOfDay.fromDateTime(lesson.startTime);
      _endTime = TimeOfDay.fromDateTime(lesson.endTime);
      _notesController.text = lesson.notes ?? '';
      _priceController.text = lesson.price?.toString() ?? '';
      try {
        _selectedStudent = widget.students.firstWhere(
          (s) => s.id == lesson.studentId,
        );
      } catch (e) {
        _selectedStudent = null;
      }
    } else if (widget.students.isNotEmpty) {
      _selectedStudent = widget.students.first;
      _priceController.text = _selectedStudent?.price.toString() ?? '';
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final student = _selectedStudent;
    if (student == null ||
        student.id == null ||
        _startTime == null ||
        _endTime == null) {
      return;
    }

    final database = AppDatabase();

    if (_applyToFutureLessons && widget.lessonToEdit != null) {
      final originalLesson = widget.lessonToEdit!;
      if (originalLesson.studentId == null) {
        return;
      }
      final lessonsToUpdate = await database.getFutureRecurringLessons(
        originalLesson.studentId!,
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
          _startTime!.hour,
          _startTime!.minute,
        );
        final newEndTime = DateTime(
          newDate.year,
          newDate.month,
          newDate.day,
          _endTime!.hour,
          _endTime!.minute,
        );

        return Lesson(
          id: lesson.id,
          studentId: lesson.studentId,
          studentName: student.name,
          studentSurname: student.surname,
          startTime: newStartTime,
          endTime: newEndTime,
          isPaid: lesson.isPaid,
          notes: _notesController.text,
          price: double.tryParse(_priceController.text),
        );
      }).toList();

      if (updatedLessons.isNotEmpty) {
        await database.updateLessons(updatedLessons);
      }
    } else if (_duplicateLessons &&
        _duplicationStartDate != null &&
        _duplicationEndDate != null) {
      final lessonsToSave = <Lesson>[];
      var currentDate = _duplicationStartDate!;
      while (currentDate.isBefore(_duplicationEndDate!) ||
          currentDate.isAtSameMomentAs(_duplicationEndDate!)) {
        if (currentDate.weekday == _lessonDate.weekday) {
          lessonsToSave.add(
            Lesson(
              studentId: student.id!,
              studentName: student.name,
              studentSurname: student.surname,
              startTime: DateTime(
                currentDate.year,
                currentDate.month,
                currentDate.day,
                _startTime!.hour,
                _startTime!.minute,
              ),
              endTime: DateTime(
                currentDate.year,
                currentDate.month,
                currentDate.day,
                _endTime!.hour,
                _endTime!.minute,
              ),
              notes: _notesController.text,
              price: double.tryParse(_priceController.text),
            ),
          );
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }

      if (widget.lessonToEdit != null) {
        await database.deleteLesson(widget.lessonToEdit!.id!);
      }

      if (lessonsToSave.isNotEmpty) {
        await database.insertLessons(lessonsToSave);
      }
    } else {
      final lessonStartTime = DateTime(
        _lessonDate.year,
        _lessonDate.month,
        _lessonDate.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      final lessonEndTime = DateTime(
        _lessonDate.year,
        _lessonDate.month,
        _lessonDate.day,
        _endTime!.hour,
        _endTime!.minute,
      );

      if (widget.lessonToEdit != null) {
        final lessonToUpdate = Lesson(
          id: widget.lessonToEdit!.id,
          studentId: student.id!,
          studentName: student.name,
          studentSurname: student.surname,
          startTime: lessonStartTime,
          endTime: lessonEndTime,
          isPaid: widget.lessonToEdit!.isPaid,
          notes: _notesController.text,
          price: double.tryParse(_priceController.text),
        );
        await database.updateLesson(lessonToUpdate);
      } else {
        final newLesson = Lesson(
          studentId: student.id!,
          studentName: student.name,
          studentSurname: student.surname,
          startTime: lessonStartTime,
          endTime: lessonEndTime,
          notes: _notesController.text,
          price: double.tryParse(_priceController.text),
        );
        await database.insertLesson(newLesson);
      }
    }

    if (mounted) {
      Navigator.pop(context, true);
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
                    trailing: Text(DateFormat('dd.MM.yy').format(_lessonDate)),
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
                    ),
                    onTap: () => _selectTime(false),
                  ),
                ],
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
                      if (newValue != null) {
                        _priceController.text = newValue.price.toString();
                      }
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

            _buildSectionTitle('Финансы'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Цена',
                    border: InputBorder.none,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
            _buildSectionTitle('Примечания'),
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
                  maxLines: 3,
                ),
              ),
            ),

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
                        if (_duplicateLessons) {
                          _applyToFutureLessons = false;
                        }
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
                          if (_applyToFutureLessons) {
                            _duplicateLessons = false;
                          }
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
