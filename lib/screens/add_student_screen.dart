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
        title: Text(
          widget.student == null ? 'Добавить ученика' : 'Редактировать ученика',
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Имя *
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Имя *',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.deepPurple,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите имя';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Фамилия
                    TextFormField(
                      controller: _surnameController,
                      decoration: InputDecoration(
                        labelText: 'Фамилия',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.deepPurple,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildSectionTitle('Контакты'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Телефон
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Телефон',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.deepPurple,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.deepPurple,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Список мессенджеров
                    ..._messengers.map(
                      (messenger) => Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ListTile(
                          title: Text(
                            '${messenger['type']}: ${messenger['value']}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                setState(() => _messengers.remove(messenger)),
                          ),
                        ),
                      ),
                    ),

                    // Кнопка "Добавить мессенджер"
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurple),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.add,
                          color: Colors.deepPurple,
                        ),
                        title: const Text(
                          'Добавить мессенджер',
                          style: TextStyle(color: Colors.deepPurple),
                        ),
                        onTap: _showAddMessengerDialog,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildSectionTitle('Финансы'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Цена за одно занятие *
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Цена за одно занятие *',
                        // BYN справа
                        suffix: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            'BYN',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.only(
                          left: 16,
                          top: 12,
                          bottom: 12,
                          right: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.deepPurple,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите цену';
                        }
                        if (double.tryParse(value.replaceAll(',', '.')) ==
                            null) {
                          return 'Пожалуйста, введите число';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Авто-оплата занятия
                    InkWell(
                      onTap: () => setState(() => _autoPay = !_autoPay),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _autoPay
                              ? Colors.deepPurple.withOpacity(0.05)
                              : Colors.transparent,
                          border: Border.all(
                            color: _autoPay
                                ? Colors.deepPurple
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _autoPay,
                              onChanged: (v) =>
                                  setState(() => _autoPay = v ?? false),
                              activeColor: Colors.deepPurple,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'После проведения занятия считать его автоматически оплаченным',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildSectionTitle('Примечания'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Добавьте примечание к занятию...',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
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
          fontSize: 16,
        ),
      ),
    );
  }
}
