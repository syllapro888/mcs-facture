class Client {
  final int? id;
  final String name;
  final String phone;
  final String address;
  final String email;
  final String notes;

  const Client({
    this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.email = '',
    this.notes = '',
  });

  Client copyWith({int? id}) => Client(
        id: id ?? this.id,
        name: name,
        phone: phone,
        address: address,
        email: email,
        notes: notes,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'email': email,
        'notes': notes,
      };

  factory Client.fromMap(Map<String, Object?> m) => Client(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
      );
}
