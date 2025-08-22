import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/student.dart';

import 'package:rephelp/screens/add_student_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Student> _activeStudents = [];
  List<Student> _filteredActiveStudents = [];
  List<Student> _archivedStudents = [];
  List<Student> _filteredArchivedStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStudents();
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Метод для загрузки учеников из базы данных
  Future<void> _loadStudents() async {
    final database = AppDatabase();
    final activeStudents = await database.getStudents(isArchived: false);
    final archivedStudents = await database.getStudents(isArchived: true);
    if (!mounted) return;
    setState(() {
      _activeStudents = activeStudents;
      _filteredActiveStudents = activeStudents;
      _archivedStudents = archivedStudents;
      _filteredArchivedStudents = archivedStudents;
      _isLoading = false;
    });
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredActiveStudents = _activeStudents.where((student) {
        final fullName = '${student.name} ${student.surname ?? ''}'.toLowerCase();
        return fullName.contains(query);
      }).toList();
      _filteredArchivedStudents = _archivedStudents.where((student) {
        final fullName = '${student.name} ${student.surname ?? ''}'.toLowerCase();
        return fullName.contains(query);
      }).toList();
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

  Future<void> _toggleArchiveStatus(int id, bool isArchived) async {
    await AppDatabase().setStudentArchived(id, isArchived);
    _loadStudents(); // Перезагружаем списки
  }

  Future<void> _deleteStudent(int id) async {
    await AppDatabase().deleteStudent(id);
    _loadStudents(); // Перезагружаем списки
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Активные'),
            Tab(text: 'Архив'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск ученика',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStudentList(_filteredActiveStudents, false),
                      _buildStudentList(_filteredArchivedStudents, true),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddStudentScreen()),
          );
          if (result == true) {
            _loadStudents();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStudentList(List<Student> students, bool isArchived) {
    if (_searchController.text.isNotEmpty && students.isEmpty) {
      return const Center(child: Text('Совпадений не найдено'));
    }
    if (students.isEmpty) {
      return Center(
        child: Text(
          isArchived ? 'Архив пуст' : 'Ученики не найдены. Добавьте нового.',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8.0),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColorLight,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text('${student.name} ${student.surname ?? ''}'),
            onTap: () => _editStudent(student),
            trailing: isArchived
                ? IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showArchiveMenu(context, student),
                  )
                : IconButton(
                    icon: const Icon(Icons.archive),
                    onPressed: () => _toggleArchiveStatus(student.id!, true),
                  ),
          ),
        );
      },
    );
  }

  void _showArchiveMenu(BuildContext context, Student student) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: AlertDialog(
            title: Text('${student.name} ${student.surname ?? ''}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.unarchive),
                  title: const Text('Перенести в активные'),
                  onTap: () {
                    _toggleArchiveStatus(student.id!, false);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Удалить'),
                  onTap: () {
                    _deleteStudent(student.id!);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Отмена'),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
