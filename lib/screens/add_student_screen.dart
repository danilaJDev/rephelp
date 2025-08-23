import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/student.dart';
import 'dart:convert';
import 'package:rephelp/widgets/custom_app_bar.dart';

class AddStudentScreen extends StatefulWidget {
  final Student? student;

  const AddStudentScreen({super.key, this.student});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, String>> _messengers = [];
  bool _autoPay = false;
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
        try {
          _messengers = (jsonDecode(student.messengers!) as List)
              .map((item) => Map<String, String>.from(item))
              .toList();
        } catch (e) {
          _messengers = [];
        }
      }
    }
    _nameController.addListener(_validateForm);
    _priceController.addListener(_validateForm);
    _validateForm();
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
    final isValid =
        _nameController.text.isNotEmpty &&
        _priceController.text.isNotEmpty &&
        double.tryParse(_priceController.text) != null;
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      final studentToSave = Student(
        id: widget.student?.id,
        name: _nameController.text,
        surname: _surnameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        messengers: jsonEncode(_messengers),
        price: double.tryParse(_priceController.text) ?? 0.0,
        autoPay: _autoPay,
        notes: _notesController.text,
      );

      final database = AppDatabase();

      if (studentToSave.id != null) {
        await database.updateStudent(studentToSave);
      } else {
        await database.insertStudent(studentToSave);
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
                    .map(
                      (messenger) => DropdownMenuItem(
                        value: messenger,
                        child: Text(messenger),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedMessenger = value;
                  }
                },
              ),
              TextField(
                controller: messengerController,
                decoration: const InputDecoration(
                  labelText: 'Номер/Имя пользователя',
                ),
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
      appBar: CustomAppBar(
        title: widget.student == null ? 'Новый ученик' : 'Редактировать',
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
              onPressed: _isFormValid ? _saveStudent : null,
            ),
          ),
        ],
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(10.0),
          children: [
            _buildSectionTitle('Общая информация'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя *',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Пожалуйста, введите имя';
                      return null;
                    },
                  ),
                  const Divider(height: 1, color: Colors.grey),
                  TextFormField(
                    controller: _surnameController,
                    decoration: const InputDecoration(
                      labelText: 'Фамилия',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _buildSectionTitle('Контакты'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Телефон',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const Divider(height: 1, color: Colors.grey),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const Divider(height: 1, color: Colors.grey),
                  ..._messengers.map((messenger) {
                    return ListTile(
                      title: Text(
                        '${messenger['type']}: ${messenger['value']}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            setState(() => _messengers.remove(messenger)),
                      ),
                    );
                  }),
                  const Divider(height: 1, color: Colors.grey),
                  ListTile(
                    leading: const Icon(Icons.add, color: Colors.deepPurple),
                    title: const Text(
                      'Добавить мессенджер',
                      style: TextStyle(color: Colors.deepPurple),
                    ),
                    onTap: _showAddMessengerDialog,
                  ),
                ],
              ),
            ),

            _buildSectionTitle('Финансы'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Цена за одно занятие *',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Пожалуйста, введите цену';
                      if (double.tryParse(value) == null)
                        return 'Пожалуйста, введите число';
                      return null;
                    },
                  ),
                  const Divider(height: 1, color: Colors.grey),
                  CheckboxListTile(
                    title: const Text(
                      'После проведения занятия считать его автоматически оплаченным',
                    ),
                    value: _autoPay,
                    onChanged: (bool? value) =>
                        setState(() => _autoPay = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.deepPurple,
                  ),
                ],
              ),
            ),

            _buildSectionTitle('Примечания'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'Добавьте примечание...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: 3,
              ),
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
}
