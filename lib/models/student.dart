import 'dart:convert';

class Student {
  final int? id;
  final String name;
  final String? surname;
  final String? phone;
  final String? email;
  final String? messengers; // JSON string for list of messengers
  final double price;
  final bool autoPay;
  final String? notes;

  Student({
    this.id,
    required this.name,
    this.surname,
    this.phone,
    this.email,
    this.messengers,
    required this.price,
    required this.autoPay,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'phone': phone,
      'email': email,
      'messengers': messengers,
      'price': price,
      'autoPay': autoPay ? 1 : 0, // Store bool as int
      'notes': notes,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      name: map['name'] as String,
      surname: map['surname'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      messengers: map['messengers'] as String?,
      price: map['price'] as double,
      autoPay: map['autoPay'] == 1, // Read int as bool
      notes: map['notes'] as String?,
    );
  }
}