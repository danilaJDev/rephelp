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
  Student? _selectedStudent;

  @override
  void initState() {
    super.initState();
    if (widget.lessonToEdit != null) {
      try {
        _selectedStudent = widget.students.firstWhere(
          (s) => s.id == widget.lessonToEdit!.studentId,
        );
      } catch (e) {
        if (widget.students.isNotEmpty) {
          _selectedStudent = widget.students.first;
        }
      }
    } else if (widget.students.isNotEmpty) {
      _selectedStudent = widget.students.first;
    }
  }

  Future<void> _saveLesson() async {
    final student = _selectedStudent;
    if (student != null && student.id != null) {
      final AppDatabase database = AppDatabase();
      final newLesson = Lesson(
        id: widget.lessonToEdit?.id,
        studentId: student.id!,
        startTime: widget.selectedDate,
        endTime: widget.selectedDate.add(const Duration(hours: 1)),
        isPaid: widget.lessonToEdit?.isPaid ?? false,
      );
      if (newLesson.id != null) {
        await database.updateLesson(newLesson);
      } else {
        await database.insertLesson(newLesson);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите ученика.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.lessonToEdit != null
            ? 'Редактировать занятие'
            : 'Добавить занятие',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _saveLesson,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(10.0),
        children: [
          Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Дата: ${DateFormat.yMMMd('ru').format(widget.selectedDate)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text('Ученик:', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  if (widget.students.isNotEmpty)
                    DropdownButtonFormField<Student>(
                      value: _selectedStudent,
                      onChanged: (Student? newValue) {
                        setState(() {
                          _selectedStudent = newValue;
                        });
                      },
                      items: widget.students.map<DropdownMenuItem<Student>>((
                        Student student,
                      ) {
                        return DropdownMenuItem<Student>(
                          value: student,
                          child: Text('${student.name} ${student.surname ?? ''}'),
                        );
                      }).toList(),
                      isExpanded: true,
                    )
                  else
                    const Text('Нет доступных учеников.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
