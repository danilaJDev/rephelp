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

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        notes TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE lessons(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER,
        start_time INTEGER,
        end_time INTEGER,
        is_paid INTEGER,
        notes TEXT,
        FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
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
    if (oldVersion < 3) {
      await db.execute('''
      ALTER TABLE students ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0
    ''');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE lessons RENAME TO lessons_old');
      await db.execute('''
        CREATE TABLE lessons(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER,
          start_time INTEGER,
          end_time INTEGER,
          is_paid INTEGER,
          FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
        )
      ''');
      final List<Map<String, dynamic>> oldLessons = await db.query(
        'lessons_old',
      );
      for (final oldLesson in oldLessons) {
        final startTime = oldLesson['date'];
        final endTime = startTime != null ? startTime + 3600000 : null;
        await db.insert('lessons', {
          'id': oldLesson['id'],
          'student_id': oldLesson['student_id'],
          'start_time': startTime,
          'end_time': endTime,
          'is_paid': oldLesson['is_paid'],
        });
      }
      await db.execute('DROP TABLE lessons_old');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE lessons ADD COLUMN notes TEXT');
    }
  }

  Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert('students', student.toMap());
  }

  Future<List<Student>> getStudents({bool isArchived = false}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'is_archived = ?',
      whereArgs: [isArchived ? 1 : 0],
    );

    return List.generate(maps.length, (i) {
      return Student.fromMap(maps[i]);
    });
  }

  Future<int> setStudentArchived(int id, bool isArchived) async {
    final db = await database;
    return await db.update(
      'students',
      {'is_archived': isArchived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateStudent(Student student) async {
    final db = await database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertLesson(Lesson lesson) async {
    final db = await database;
    return await db.insert('lessons', lesson.toMap());
  }

  Future<void> insertLessons(List<Lesson> lessons) async {
    final db = await database;
    final batch = db.batch();
    for (var lesson in lessons) {
      batch.insert('lessons', lesson.toMap());
    }
    await batch.commit();
  }

  Future<List<Lesson>> getLessonsByDate(DateTime date) async {
    final db = await database;
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
      where: 'start_time BETWEEN ? AND ?',
      whereArgs: [startOfDay, endOfDay],
    );

    return List.generate(maps.length, (i) {
      return Lesson.fromMap(maps[i]);
    });
  }

  Future<List<Lesson>> getAllLessons() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('lessons');
    return List.generate(maps.length, (i) {
      return Lesson.fromMap(maps[i]);
    });
  }

  Future<Map<String, dynamic>> getLessonWithStudent(int lessonId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
    SELECT
      lessons.id,
      lessons.start_time,
      lessons.end_time,
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

  Future<void> updateLesson(Lesson lesson) async {
    final db = await database;
    await db.update(
      'lessons',
      lesson.toMap(),
      where: 'id = ?',
      whereArgs: [lesson.id],
    );
  }

  Future<void> deleteLesson(int id) async {
    final db = await database;
    await db.delete('lessons', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateLessons(List<Lesson> lessons) async {
    final db = await database;
    final batch = db.batch();
    for (var lesson in lessons) {
      batch.update(
        'lessons',
        lesson.toMap(),
        where: 'id = ?',
        whereArgs: [lesson.id],
      );
    }
    await batch.commit();
  }

  Future<List<Lesson>> getFutureRecurringLessons(
    int studentId,
    DateTime startTime,
  ) async {
    final db = await database;
    final startTimeMillis = startTime.millisecondsSinceEpoch;
    final sqliteWeekday = (startTime.weekday % 7).toString();

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT * FROM lessons
      WHERE student_id = ?
      AND start_time >= ?
      AND strftime('%w', start_time / 1000, 'unixepoch') = ?
    ''',
      [studentId, startTimeMillis, sqliteWeekday],
    );

    return List.generate(maps.length, (i) {
      return Lesson.fromMap(maps[i]);
    });
  }

  Future<void> deleteFutureRecurringLessons(
    int studentId,
    DateTime startTime,
  ) async {
    final db = await database;
    final startTimeMillis = startTime.millisecondsSinceEpoch;
    // Dart: Mon=1..Sun=7, SQLite's strftime('%w',...): Sun=0..Sat=6
    final sqliteWeekday = (startTime.weekday % 7).toString();

    await db.rawDelete(
      '''
      DELETE FROM lessons
      WHERE student_id = ?
      AND start_time >= ?
      AND strftime('%w', start_time / 1000, 'unixepoch') = ?
      ''',
      [studentId, startTimeMillis, sqliteWeekday],
    );
  }

  Future<void> updateLessonIsPaid(int lessonId, bool isPaid) async {
    final db = await database;
    await db.update(
      'lessons',
      {'is_paid': isPaid ? 1 : 0},
      where: 'id = ?',
      whereArgs: [lessonId],
    );
  }

  Future<List<Map<String, dynamic>>> getFinancialData() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT
      lessons.id,
      lessons.start_time,
      lessons.end_time,
      lessons.is_paid,
      students.name,
      students.price
    FROM lessons
    INNER JOIN students ON lessons.student_id = students.id
    ORDER BY lessons.start_time DESC;
  ''');
  }
}
