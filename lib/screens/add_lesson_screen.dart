import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/lesson.dart';
import 'package:rephelp/models/student.dart';

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
      // Если передано занятие для редактирования, находим и выбираем ученика
      _selectedStudent = widget.students.firstWhere(
        (s) => s.id == widget.lessonToEdit!.studentId,
      );
    } else if (widget.students.isNotEmpty) {
      // Иначе, если список не пуст, выбираем первого
      _selectedStudent = widget.students.first;
    }
  }

  Future<void> _saveLesson() async {
    if (_selectedStudent != null) {
      final AppDatabase database = AppDatabase();
      final newLesson = Lesson(
        id: widget.lessonToEdit?.id, // Передаем ID, если это редактирование
        studentId: _selectedStudent!.id!,
        date: widget.selectedDate,
        isPaid: widget.lessonToEdit?.isPaid ?? false, // Сохраняем статус оплаты
      );
      if (newLesson.id != null) {
        // Если ID существует, обновляем
        await database.updateLesson(newLesson);
      } else {
        // Иначе создаем новое занятие
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
      appBar: AppBar(
        title: Text(
          widget.lessonToEdit != null
              ? 'Редактировать занятие'
              : 'Добавить занятие',
        ),
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Дата: ${widget.selectedDate.toLocal().toString().split(' ')[0]}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            const Text('Выберите ученика:', style: TextStyle(fontSize: 16)),
            DropdownButton<Student>(
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
                  child: Text(student.name),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveLesson,
              child: const Text('Сохранить занятие'),
            ),
          ],
        ),
      ),
    );
  }
}
