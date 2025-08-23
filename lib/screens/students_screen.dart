import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/student.dart';
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
      appBar: CustomAppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Text('Ученики', style: TextStyle(fontSize: 24)),
        ),
      ),
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
                      insets: EdgeInsets.symmetric(horizontal: 100),
                    ),

                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(fontSize: 14),

                    tabs: const [
                      Tab(
                        icon: Icon(Icons.person),
                        child: Text(
                          'Активные',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Tab(
                        icon: Icon(Icons.archive),
                        child: Text(
                          'Архив',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск ученика',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15.0),
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
      padding: const EdgeInsets.only(top: 10.0),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              '${student.name} ${student.surname ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            onTap: () => _editStudent(student),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.deepPurple),
              onPressed: () {
                if (isArchived) {
                  _showArchiveMenu(context, student);
                } else {
                  _showActiveMenu(context, student);
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _showActiveMenu(BuildContext context, Student student) {
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
                const Icon(Icons.person, size: 30),
                const SizedBox(height: 10),
                Text('${student.name} ${student.surname ?? ''}'),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Редактировать'),
                iconColor: Colors.blue,
                onTap: () {
                  Navigator.of(context).pop();
                  _editStudent(student);
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive),
                iconColor: Colors.orange,
                title: const Text('Архивировать'),
                onTap: () {
                  Navigator.of(context).pop();
                  _toggleArchiveStatus(student.id!, true);
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
                const Icon(Icons.person, size: 30),
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
                iconColor: Colors.green,
                onTap: () {
                  _toggleArchiveStatus(student.id!, false);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                iconColor: Colors.red,
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
