import 'day_status.dart';
import 'habit.dart';

/// Un hábito junto con la información derivada de su historial diario.
///
/// Esta clase es la que consume la UI: permite saber de forma inmediata
/// (sin consultar la base de datos de nuevo) el estado de un día concreto,
/// la racha actual y la racha máxima del hábito.
class HabitProgress {
  final Habit habit;

  /// Estado registrado por día (normalizado, sin hora).
  ///
  /// Es un mapa mutable a propósito: el provider lo actualiza de forma
  /// optimista al marcar/desmarcar y luego persiste el cambio en sqflite.
  final Map<DateTime, DayStatus> dayStatuses;

  HabitProgress({
    required this.habit,
    Map<DateTime, DayStatus>? dayStatuses,
  }) : dayStatuses = dayStatuses ?? <DateTime, DayStatus>{};

  /// Normaliza un [DateTime] dejando solo año, mes y día.
  ///
  /// Se usa `DateTime.utc` para que la aritmética de días (restar 24 h,
  /// calcular diferencias) nunca se vea afectada por cambios de horario
  /// de verano.
  static DateTime dayOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Estado registrado para [day]; `null` si el día no se ha marcado.
  DayStatus? statusOn(DateTime day) => dayStatuses[dayOnly(day)];

  /// ¿El hábito se completó (o está completado) en [day]?
  bool isCompletedOn(DateTime day) => statusOn(day) == DayStatus.completed;

  /// ¿El día se marcó como complicado (no cumplido)?
  bool isDifficultOn(DateTime day) => statusOn(day) == DayStatus.difficult;

  /// Estado del día de hoy (`null` = sin marcar).
  DayStatus? get statusToday => statusOn(DateTime.now());

  bool get isCompletedToday => isCompletedOn(DateTime.now());

  bool get isDifficultToday => isDifficultOn(DateTime.now());

  /// Registra (o borra, con `null`) el estado de [day] en memoria.
  ///
  /// La persistencia en base de datos la gestiona el provider.
  void setStatus(DateTime day, DayStatus? status) {
    if (status == null) {
      dayStatuses.remove(dayOnly(day));
    } else {
      dayStatuses[dayOnly(day)] = status;
    }
  }

  /// Total de días completados a lo largo de todo el historial.
  int get totalCompleted =>
      dayStatuses.values.where((s) => s == DayStatus.completed).length;

  /// Total de días complicados a lo largo de todo el historial.
  int get totalDifficult =>
      dayStatuses.values.where((s) => s == DayStatus.difficult).length;

  /// Conjunto de días completados (base para calcular las rachas).
  Set<DateTime> get _completedDays => dayStatuses.entries
      .where((e) => e.value == DayStatus.completed)
      .map((e) => e.key)
      .toSet();

  /// Racha actual, en días consecutivos completados.
  ///
  /// Un día marcado como complicado rompe la racha. Si hoy todavía no se
  /// ha marcado nada, la racha NO se considera rota: se cuenta desde ayer
  /// hacia atrás, porque el día de hoy aún no termina.
  int get currentStreak {
    final days = _completedDays;
    var cursor = dayOnly(DateTime.now());
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Racha máxima alcanzada históricamente (mayor número de días
  /// consecutivos completados en cualquier momento).
  int get maxStreak {
    final sorted = _completedDays.toList()..sort();
    var max = 0;
    var run = 0;
    DateTime? prev;
    for (final day in sorted) {
      run = (prev != null && day.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > max) max = run;
      prev = day;
    }
    return max;
  }
}
