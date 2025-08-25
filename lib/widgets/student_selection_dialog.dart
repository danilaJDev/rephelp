import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/student.dart';

class StudentSelectionDialog extends StatefulWidget {
  final List<int> initialSelectedIds;

  const StudentSelectionDialog({super.key, required this.initialSelectedIds});

  @override
  State<StudentSelectionDialog> createState() => _StudentSelectionDialogState();
}

class _StudentSelectionDialogState extends State<StudentSelectionDialog> {
  List<Student> _allStudents = [];
  late Set<int> _selectedIds;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final students = await AppDatabase().getStudents(isArchived: false);
    if (mounted) {
      setState(() {
        _allStudents = students;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Мои ученики', textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedIds.clear();
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('Очистить все'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedIds.addAll(_allStudents.map((s) => s.id!));
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Выбрать все'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: Container(
                      color: Colors.grey[200],
                      child: ListView.builder(
                        itemCount: _allStudents.length,
                        itemBuilder: (context, index) {
                          final student = _allStudents[index];
                          final isSelected = _selectedIds.contains(student.id);

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey[300]!,
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ListTile(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(student.id);
                                  } else {
                                    _selectedIds.add(student.id!);
                                  }
                                });
                              },
                              leading: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedIds.remove(student.id);
                                    } else {
                                      _selectedIds.add(student.id!);
                                    }
                                  });
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.green
                                          : Colors.grey,
                                      width: 2,
                                    ),
                                    color: isSelected
                                        ? Colors.green
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : null,
                                ),
                              ),
                              title: Text(
                                '${student.name} ${student.surname ?? ''}',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.deepPurple),
            foregroundColor: Colors.deepPurple,
          ),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedIds.toList());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
