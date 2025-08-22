import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/student.dart';
import 'package:rephelp/utils/app_colors.dart';
import 'package:rephelp/widgets/custom_app_bar.dart';

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
    _searchController.dispose();
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
        final fullName = '${student.name} ${student.surname ?? ''}'
            .toLowerCase();
        return fullName.contains(query);
      }).toList();
      _filteredArchivedStudents = _archivedStudents.where((student) {
        final fullName = '${student.name} ${student.surname ?? ''}'
            .toLowerCase();
        return fullName.contains(query);
      }).toList();
    });
  }

  Future<void> _editStudent(Student student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStudentScreen(student: student),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _loadStudents();
    }
  }

  Future<void> _toggleArchiveStatus(int id, bool isArchived) async {
    await AppDatabase().setStudentArchived(id, isArchived);
    _loadStudents();
  }

  Future<void> _deleteStudent(int id) async {
    await AppDatabase().deleteStudent(id);
    _loadStudents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Ученики'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(color: Colors.white, width: 3),
                      insets: EdgeInsets.symmetric(horizontal: 100.0),
                    ),
                    tabs: const [
                      Tab(
                        child: Text(
                          'Активные',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Tab(
                        child: Text(
                          'Архив',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск ученика',
                      hintStyle: const TextStyle(color: AppColors.mutedText),
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
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
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
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.lavender,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              '${student.name} ${student.surname ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            onTap: () => _editStudent(student),
            trailing: isArchived
                ? IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showArchiveMenu(context, student),
                  )
                : IconButton(
                    icon: const Icon(Icons.archive, color: AppColors.lavender),
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
        );
      },
    );
  }
}
