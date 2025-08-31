class Lesson {
  final int? id;
  final int? studentId;
  final String? studentName;
  final String? studentSurname;
  final DateTime startTime;
  final DateTime endTime;
  final bool isPaid;
  final String? notes;
  final double? price;
  final bool isHomeworkSent;
  final bool isHidden;

  Lesson({
    this.id,
    this.studentId,
    this.studentName,
    this.studentSurname,
    required this.startTime,
    required this.endTime,
    this.isPaid = false,
    this.notes,
    this.price,
    this.isHomeworkSent = false,
    this.isHidden = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'student_surname': studentSurname,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'is_paid': isPaid ? 1 : 0,
      'notes': notes,
      'price': price,
      'is_homework_sent': isHomeworkSent ? 1 : 0,
      'is_hidden': isHidden ? 1 : 0,
    };
  }

  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'] as int?,
      studentId: map['student_id'] as int?,
      studentName: map['student_name'] as String?,
      studentSurname: map['student_surname'] as String?,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      isPaid: (map['is_paid'] as int) == 1,
      notes: map['notes'] as String?,
      price: map['price'] as double?,
      isHomeworkSent: (map['is_homework_sent'] as int? ?? 0) == 1,
      isHidden: (map['is_hidden'] as int? ?? 0) == 1,
    );
  }
}
