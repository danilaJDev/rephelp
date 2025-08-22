class Lesson {
  final int? id;
  final int studentId;
  final DateTime date;
  final bool isPaid;

  Lesson({
    this.id,
    required this.studentId,
    required this.date,
    this.isPaid = false,
  });

  // Метод для преобразования объекта Lesson в Map (для сохранения в базу данных)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'date': date.millisecondsSinceEpoch,
      'is_paid': isPaid ? 1 : 0,
    };
  }

  // Метод для создания объекта Lesson из Map (для чтения из базы данных)
  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      isPaid: (map['is_paid'] as int) == 1,
    );
  }
}