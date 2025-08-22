import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:rephelp/models/student.dart';
import 'package:rephelp/models/lesson.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'rephelp_database.db');

    return await openDatabase(path,
        version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        surname TEXT,
        phone TEXT,
        email TEXT,
        messengers TEXT,
        price REAL NOT NULL,
        autoPay INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE lessons(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER,
        date INTEGER,
        is_paid INTEGER,
        FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // await db.execute('DROP TABLE IF EXISTS students');
      // await db.execute('DROP TABLE IF EXISTS lessons');
      // await _onCreate(db, newVersion);
      await db.execute('''
      ALTER TABLE students ADD COLUMN surname TEXT
    ''');
      await db.execute('''
      ALTER TABLE students ADD COLUMN phone TEXT
    ''');
      await db.execute('''
      ALTER TABLE students ADD COLUMN email TEXT
    ''');
      await db.execute('''
      ALTER TABLE students ADD COLUMN messengers TEXT
    ''');
      await db.execute('''
      ALTER TABLE students ADD COLUMN autoPay INTEGER NOT NULL DEFAULT 0
    ''');
    }
  }

  // --- Методы для работы с учениками ---

  // Создание (добавление) нового ученика
  Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert('students', student.toMap());
  }

  // Чтение (получение) всех учеников
  Future<List<Student>> getStudents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('students');

    return List.generate(maps.length, (i) {
      return Student.fromMap(maps[i]);
    });
  }

  // Обновление данных ученика
  Future<int> updateStudent(Student student) async {
    final db = await database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  // Удаление ученика
  Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  // --- Методы для работы с занятиями ---

  // Создание (добавление) нового занятия
  Future<int> insertLesson(Lesson lesson) async {
    final db = await database;
    return await db.insert('lessons', lesson.toMap());
  }

  // Метод для пакетной вставки нескольких занятий
  Future<void> insertLessons(List<Lesson> lessons) async {
    final db = await database;
    final batch = db.batch();
    for (var lesson in lessons) {
      batch.insert('lessons', lesson.toMap());
    }
    await batch.commit();
  }

  // Получение занятий для определенной даты
  Future<List<Lesson>> getLessonsByDate(DateTime date) async {
    final db = await database;
    // Преобразуем дату в миллисекунды для сравнения в базе данных
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).millisecondsSinceEpoch;

    final List<Map<String, dynamic>> maps = await db.query(
      'lessons',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startOfDay, endOfDay],
    );

    return List.generate(maps.length, (i) {
      return Lesson.fromMap(maps[i]);
    });
  }

  // Получение всех занятий
  Future<List<Lesson>> getAllLessons() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('lessons');
    return List.generate(maps.length, (i) {
      return Lesson.fromMap(maps[i]);
    });
  }

  // Получение информации о занятии с данными ученика
  Future<Map<String, dynamic>> getLessonWithStudent(int lessonId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
    SELECT
      lessons.id,
      lessons.date,
      lessons.is_paid,
      students.name,
      students.price
    FROM lessons
    INNER JOIN students ON lessons.student_id = students.id
    WHERE lessons.id = ?
  ''',
      [lessonId],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return {};
  }

  // Метод для обновления занятия
  Future<void> updateLesson(Lesson lesson) async {
    final db = await database;
    await db.update(
      'lessons',
      lesson.toMap(),
      where: 'id = ?',
      whereArgs: [lesson.id],
    );
  }

  // Метод для удаления занятия по ID
  Future<void> deleteLesson(int id) async {
    final db = await database;
    await db.delete('lessons', where: 'id = ?', whereArgs: [id]);
  }

  // --- Методы для работы с финансами ---

  // Обновление статуса оплаты занятия
  Future<void> updateLessonIsPaid(int lessonId, bool isPaid) async {
    final db = await database;
    await db.update(
      'lessons',
      {'is_paid': isPaid ? 1 : 0},
      where: 'id = ?',
      whereArgs: [lessonId],
    );
  }

  // Получение всех занятий, включая данные учеников, для экрана "Финансы"
  Future<List<Map<String, dynamic>>> getFinancialData() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT
      lessons.id,
      lessons.date,
      lessons.is_paid,
      students.name,
      students.price
    FROM lessons
    INNER JOIN students ON lessons.student_id = students.id
    ORDER BY lessons.date DESC;
  ''');
  }
}
