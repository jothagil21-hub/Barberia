class BarberService {
  const BarberService({
    required this.id,
    required this.name,
    this.price = 0,
    this.durationMinutes = 30,
    this.isActive = true,
  });

  final int id;
  final String name;
  final double price;
  final int durationMinutes;
  final bool isActive;

  factory BarberService.fromMap(Map<String, Object?> map) {
    return BarberService(
      id: map['id'] as int,
      name: map['name'] as String,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      durationMinutes: map['duration_minutes'] as int? ?? 30,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'duration_minutes': durationMinutes,
      'is_active': isActive ? 1 : 0,
    };
  }
}
