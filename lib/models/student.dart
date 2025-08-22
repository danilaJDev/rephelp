class Student {
  final int? id;
  final String name;
  final String? surname;
  final String? phone;
  final String? email;
  final String? messengers;
  final double price;
  final bool autoPay;
  final String? notes;
  final bool isArchived;

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
    this.isArchived = false,
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
      'autoPay': autoPay ? 1 : 0,
      'notes': notes,
      'is_archived': isArchived ? 1 : 0,
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
      autoPay: map['autoPay'] == 1,
      notes: map['notes'] as String?,
      isArchived: map['is_archived'] == 1,
    );
  }
}
