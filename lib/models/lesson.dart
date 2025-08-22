class Lesson {
  final int? id;
  final int studentId;
  final DateTime startTime;
  final DateTime endTime;
  final bool isPaid;

  Lesson({
    this.id,
    required this.studentId,
    required this.startTime,
    required this.endTime,
    this.isPaid = false,
  });

  // Метод для преобразования объекта Lesson в Map (для сохранения в базу данных)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'is_paid': isPaid ? 1 : 0,
    };
  }

  // Метод для создания объекта Lesson из Map (для чтения из базы данных)
  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      isPaid: (map['is_paid'] as int) == 1,
    );
  }
}