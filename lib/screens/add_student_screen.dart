import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:rephelp/models/student.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:rephelp/models/lesson.dart';
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

  List<Map<String, dynamic>> _lessonDays = [];
  bool _duplicateLessons = false;
  DateTime? _startDate;
  DateTime? _endDate;

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
      int studentId;

      if (studentToSave.id != null) {
        await database.updateStudent(studentToSave);
        studentId = studentToSave.id!;
      } else {
        studentId = await database.insertStudent(studentToSave);
      }

      if (_duplicateLessons &&
          _startDate != null &&
          _endDate != null &&
          _lessonDays.isNotEmpty) {
        final lessonsToCreate = <Lesson>[];
        final Map<String, int> weekDayMap = {
          'Понедельник': DateTime.monday,
          'Вторник': DateTime.tuesday,
          'Среда': DateTime.wednesday,
          'Четверг': DateTime.thursday,
          'Пятница': DateTime.friday,
          'Суббота': DateTime.saturday,
          'Воскресенье': DateTime.sunday,
        };

        for (var lessonDay in _lessonDays) {
          final weekDay = weekDayMap[lessonDay['day']];
          final startTime = lessonDay['startTime'] as TimeOfDay;
          final endTime = lessonDay['endTime'] as TimeOfDay;

          if (weekDay != null) {
            var currentDate = _startDate!;
            while (currentDate.isBefore(_endDate!) ||
                currentDate.isAtSameMomentAs(_endDate!)) {
              if (currentDate.weekday == weekDay) {
                final lessonStartTime = DateTime(
                  currentDate.year,
                  currentDate.month,
                  currentDate.day,
                  startTime.hour,
                  startTime.minute,
                );
                final lessonEndTime = DateTime(
                  currentDate.year,
                  currentDate.month,
                  currentDate.day,
                  endTime.hour,
                  endTime.minute,
                );
                lessonsToCreate.add(
                  Lesson(
                    studentId: studentId,
                    startTime: lessonStartTime,
                    endTime: lessonEndTime,
                  ),
                );
              }
              currentDate = currentDate.add(const Duration(days: 1));
            }
          }
        }
        if (lessonsToCreate.isNotEmpty) {
          await database.insertLessons(lessonsToCreate);
        }
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
          IconButton(
            icon: Icon(
              Icons.check,
              color: _isFormValid ? Colors.white : Colors.white54,
            ),
            onPressed: _isFormValid ? _saveStudent : null,
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

            _buildSectionTitle('Занятия'),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Column(
                children: [
                  ..._lessonDays.map((lesson) {
                    final startTime = (lesson['startTime'] as TimeOfDay).format(
                      context,
                    );
                    final endTime = (lesson['endTime'] as TimeOfDay).format(
                      context,
                    );
                    return ListTile(
                      title: Text('${lesson['day']} - $startTime-$endTime'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            setState(() => _lessonDays.remove(lesson)),
                      ),
                    );
                  }),
                  ListTile(
                    leading: const Icon(Icons.add, color: Colors.deepPurple),
                    title: const Text(
                      'Добавить день занятия',
                      style: TextStyle(color: Colors.deepPurple),
                    ),
                    onTap: _showAddLessonDayDialog,
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    title: const Text('Дублировать занятия'),
                    value: _duplicateLessons,
                    onChanged: (bool? value) {
                      setState(() {
                        _duplicateLessons = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.deepPurple,
                  ),

                  if (_duplicateLessons) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.calendar_today,
                        color: Colors.deepPurple,
                      ),
                      title: const Text('С'),
                      trailing: Text(
                        _startDate == null
                            ? 'Выберите дату'
                            : DateFormat('dd.MM.yyyy').format(_startDate!),
                      ),
                      onTap: _selectStartDate,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.calendar_today,
                        color: Colors.deepPurple,
                      ),
                      title: const Text('По'),
                      trailing: Text(
                        _endDate == null
                            ? 'Выберите дату'
                            : DateFormat('dd.MM.yyyy').format(_endDate!),
                      ),
                      onTap: _selectEndDate,
                    ),
                  ],
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

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _showAddLessonDayDialog() {
    String? selectedDay;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Добавить день и время'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDay,
                    hint: const Text('Выберите день недели'),
                    items:
                        [
                              'Понедельник',
                              'Вторник',
                              'Среда',
                              'Четверг',
                              'Пятница',
                              'Суббота',
                              'Воскресенье',
                            ]
                            .map(
                              (day) => DropdownMenuItem(
                                value: day,
                                child: Text(day),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDay = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(startTime?.format(context) ?? 'Начало'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() {
                          startTime = time;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: Text(endTime?.format(context) ?? 'Конец'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: startTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() {
                          endTime = time;
                        });
                      }
                    },
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
                    if (selectedDay != null &&
                        startTime != null &&
                        endTime != null) {
                      setState(() {
                        _lessonDays.add({
                          'day': selectedDay,
                          'startTime': startTime,
                          'endTime': endTime,
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
      },
    );
  }
}
