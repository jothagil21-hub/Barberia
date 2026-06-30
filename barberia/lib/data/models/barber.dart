class Barber {
  const Barber({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final int id;
  final String name;
  final bool isActive;

  factory Barber.fromMap(Map<String, Object?> map) {
    return Barber(
      id: map['id'] as int,
      name: map['name'] as String,
      isActive: (map['is_active'] as int) == 1,
    );
  }
}
