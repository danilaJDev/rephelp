import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/student.dart';

import 'package:rephelp/screens/add_student_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  // Список учеников, которые мы будем получать из базы данных
  List<Student> _students = [];
  bool _isLoading = true; // Флаг для отображения индикатора загрузки

  @override
  void initState() {
    super.initState();
    _loadStudents(); // Загружаем учеников при инициализации экрана
  }

  // Метод для загрузки учеников из базы данных
  Future<void> _loadStudents() async {
    final database = AppDatabase();
    final students = await database.getStudents();
    // Проверяем, что виджет все еще в дереве, прежде чем вызывать setState
    if (!mounted) return;
    setState(() {
      _students = students;
      _isLoading = false;
    });
  }

  Future<void> _editStudent(Student student) async {
    // Ждем, пока пользователь вернется с экрана редактирования
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStudentScreen(student: student),
      ),
    );
    // Проверяем, что виджет все еще в дереве
    if (!mounted) return;
    // Если результат true, значит данные изменились, и нужно обновить список
    if (result == true) {
      _loadStudents();
    }
  }

  Future<void> _deleteStudent(int id) async {
    await AppDatabase().deleteStudent(id);
    // Обновляем список учеников в памяти без повторного запроса к БД
    setState(() {
      _students.removeWhere((student) => student.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
          ? const Center(
              child: Text('Ученики не найдены. Добавьте нового ученика.'),
            )
          : ListView.builder(
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                return ListTile(
                  title: Text('${student.name} ${student.surname ?? ''}'),
                  subtitle: Text('Цена: ${student.price} руб.'),
                  onTap: () {
                    // При коротком нажатии открываем экран для редактирования
                    _editStudent(student);
                  },
                  onLongPress: () {
                    // При долгом нажатии показываем диалог удаления
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Удалить ученика?'),
                          content: Text(
                            'Вы уверены, что хотите удалить ${student.name}?',
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Отмена'),
                            ),
                            TextButton(
                              onPressed: () {
                                _deleteStudent(student.id!);
                                Navigator.pop(context); // Закрываем диалог
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
    );
  }
}
