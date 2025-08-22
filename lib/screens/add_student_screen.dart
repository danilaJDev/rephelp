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
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  // State for messengers and autoPay
  List<Map<String, String>> _messengers = [];
  bool _autoPay = false;

  // State for form validity to enable/disable save button
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      final student = widget.student!;
      _nameController.text = student.name;
      _surnameController.text = student.surname ?? '';
      _phoneController.text = student.phone ?? '';
      _emailController.text = student.email ?? '';
      _priceController.text = student.price.toString();
      _notesController.text = student.notes ?? '';
      _autoPay = student.autoPay;
      if (student.messengers != null && student.messengers!.isNotEmpty) {
        _messengers = (jsonDecode(student.messengers!) as List)
            .map((item) => Map<String, String>.from(item))
            .toList();
      }
    }
    // Add listeners to check form validity
    _nameController.addListener(_validateForm);
    _priceController.addListener(_validateForm);
    _validateForm(); // Initial validation
  }

  @override
  void dispose() {
    _nameController.removeListener(_validateForm);
    _priceController.removeListener(_validateForm);
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final isValid = _nameController.text.isNotEmpty &&
        _priceController.text.isNotEmpty &&
        double.tryParse(_priceController.text) != null;
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  // Метод для сохранения нового ученика в базу данных
  Future<void> _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      final newStudent = Student(
        id: widget.student?.id,
        name: _nameController.text,
        surname: _surnameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        messengers: jsonEncode(_messengers),
        price: double.parse(_priceController.text),
        autoPay: _autoPay,
        notes: _notesController.text,
      );

      final database = AppDatabase();
      if (newStudent.id != null) {
        await database.updateStudent(newStudent);
      } else {
        await database.insertStudent(newStudent);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  void _showAddMessengerDialog() {
    String selectedMessenger = 'Telegram';
    final messengerController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Добавить мессенджер'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedMessenger,
                items: ['Telegram', 'Viber']
                    .map((messenger) => DropdownMenuItem(
                          value: messenger,
                          child: Text(messenger),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedMessenger = value;
                  }
                },
              ),
              TextField(
                controller: messengerController,
                decoration:
                    const InputDecoration(labelText: 'Номер/Имя пользователя'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                if (messengerController.text.isNotEmpty) {
                  setState(() {
                    _messengers.add({
                      'type': selectedMessenger,
                      'value': messengerController.text,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          label: const Text('Назад', style: TextStyle(color: Colors.white)),
        ),
        leadingWidth: 100,
        title: Text(
          widget.student == null ? 'Новый ученик' : 'Редактировать',
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.check_circle,
              color: _isFormValid ? Colors.white : Colors.grey,
            ),
            onPressed: _isFormValid ? _saveStudent : null,
          ),
        ],
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildSectionTitle('Общая информация'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Имя *',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите имя';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(labelText: 'Фамилия'),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Контакты'),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Телефон'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              ..._messengers.map((messenger) {
                return ListTile(
                  title: Text('${messenger['type']}: ${messenger['value']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _messengers.remove(messenger);
                      });
                    },
                  ),
                );
              }),
              ElevatedButton.icon(
                onPressed: _showAddMessengerDialog,
                icon: const Icon(Icons.add),
                label: const Text('Добавить мессенджер'),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Финансы'),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Цена за одно занятие *',
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
              CheckboxListTile(
                title: const Text(
                    'После проведения занятия считать его автоматически оплаченным'),
                value: _autoPay,
                onChanged: (bool? value) {
                  setState(() {
                    _autoPay = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Примечания'),
              TextFormField(
                controller: _notesController,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
