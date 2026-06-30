class ServiceDurationConstants {
  ServiceDurationConstants._();

  static const int blockMinutes = 15;
  static const int minMinutes = 15;
  static const int maxMinutes = 180;
  static const int defaultMinutes = 30;

  static void validate(int minutes) {
    if (minutes < minMinutes || minutes > maxMinutes) {
      throw ArgumentError(
        'La duración debe estar entre $minMinutes y $maxMinutes minutos.',
      );
    }
    if (minutes % blockMinutes != 0) {
      throw ArgumentError(
        'La duración debe ser múltiplo de $blockMinutes minutos.',
      );
    }
  }

  static int sum(Iterable<int> durations) {
    var total = 0;
    for (final d in durations) {
      validate(d);
      total += d;
    }
    if (total < minMinutes) {
      throw ArgumentError('La duración total debe ser al menos $minMinutes min.');
    }
    return total;
  }
}
