import 'day_status.dart';

/// Modelo que representa el registro de un hábito en un día concreto.
///
/// La fecha se almacena y compara solo a nivel de día (`yyyy-MM-dd`) y
/// [status] distingue si ese día el hábito se completó o fue un día
/// complicado (no se pudo cumplir).
class HabitCompletion {
  final int? id;
  final int habitId;
  final DateTime date;
  final DayStatus status;

  const HabitCompletion({
    this.id,
    required this.habitId,
    required this.date,
    required this.status,
  });

  /// Serializa una fecha a `yyyy-MM-dd`, descartando la hora.
  static String formatDate(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final iso = day.toIso8601String(); // 'yyyy-MM-ddT00:00:00.000'
    return iso.split('T').first;
  }

  /// Convierte el modelo a un mapa para insertarlo en sqflite.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'date': formatDate(date),
      'status': status.value,
    };
  }

  /// Crea un [HabitCompletion] a partir de una fila de la base de datos.
  factory HabitCompletion.fromMap(Map<String, Object?> map) {
    return HabitCompletion(
      id: map['id'] as int?,
      habitId: map['habitId'] as int,
      // DateTime.parse sobre 'yyyy-MM-dd' produce la medianoche local
      // de ese día; la agrupación posterior normaliza a día.
      date: DateTime.parse(map['date'] as String),
      status: DayStatus.fromValue(map['status'] as String?),
    );
  }
}
