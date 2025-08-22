import 'dart:convert'; // Импортируем для работы с JSON

class Student {
  final int? id;
  final String name;
  final String contact;
  final double price;
  final String notes;
  final String schedule;

  Student({
    this.id,
    required this.name,
    required this.contact,
    required this.price,
    this.notes = '',
    this.schedule = '{}',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact': contact,
      'price': price,
      'notes': notes,
      'schedule': schedule,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      name: map['name'] as String,
      contact: map['contact'] as String,
      price: map['price'] as double,
      notes: map['notes'] as String,
      schedule: map['schedule'] as String? ?? '{}',
    );
  }
}