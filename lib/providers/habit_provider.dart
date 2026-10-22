import 'package:flutter/foundation.dart';

import '../models/day_status.dart';
import '../models/habit.dart';
import '../models/habit_progress.dart';
import '../services/database_service.dart';

/// Estado global de la aplicación: lista de hábitos con su progreso.
///
/// Extiende [ChangeNotifier] y se consume desde la UI con `provider`
/// (p. ej. `context.watch<HabitProvider>()`). Cada vez que los datos
/// cambian se llama a [notifyListeners] para repintar los widgets que
/// dependen de este estado.
class HabitProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  /// Hábitos con su estado derivado (rachas y estado de hoy).
  List<HabitProgress> habits = <HabitProgress>[];

  /// `true` mientras hay una carga en curso (para mostrar un indicador).
  bool isLoading = false;

  /// Mensaje de error de la última operación fallida; `null` si no hay.
  String? errorMessage;

  /// Carga (o recarga) los hábitos y su historial desde la base de datos.
  ///
  /// [silent] evita mostrar el indicador de carga; se usa en las
  /// recargas posteriores a crear/editar/eliminar, donde la lista ya
  /// está visible.
  Future<void> loadHabits({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }

    try {
      final habitsRaw = await _db.getHabits();
      final entries = await _db.getAllCompletions();

      // Agrupa los registros diarios por hábito (día normalizado →
      // estado) para calcular rachas y estados sin más consultas.
      final byHabit = <int, Map<DateTime, DayStatus>>{};
      for (final entry in entries) {
        byHabit
            .putIfAbsent(entry.habitId, () => <DateTime, DayStatus>{})[
                HabitProgress.dayOnly(entry.date)] =
            entry.status;
      }

      habits = habitsRaw
          .map((h) => HabitProgress(habit: h, dayStatuses: byHabit[h.id]))
          .toList();
      errorMessage = null;
    } catch (e) {
      errorMessage = 'No se pudieron cargar los hábitos: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Crea un hábito nuevo y refresca la lista.
  Future<void> addHabit(String name, String description) async {
    try {
      final habit = Habit(
        name: name.trim(),
        description: description.trim(),
        createdAt: DateTime.now(),
      );
      await _db.insertHabit(habit);
      await loadHabits(silent: true);
    } catch (e) {
      errorMessage = 'No se pudo crear el hábito: $e';
      notifyListeners();
    }
  }

  /// Edita el nombre y la descripción de un hábito existente.
  Future<void> updateHabit(
    HabitProgress progress,
    String name,
    String description,
  ) async {
    try {
      await _db.updateHabit(
        progress.habit.copyWith(
          name: name.trim(),
          description: description.trim(),
        ),
      );
      await loadHabits(silent: true);
    } catch (e) {
      errorMessage = 'No se pudo actualizar el hábito: $e';
      notifyListeners();
    }
  }

  /// Marca/desmarca el hábito como **completado** hoy.
  ///
  /// Si hoy estaba marcado como complicado, pasa a completado.
  Future<void> toggleCompletedToday(HabitProgress progress) async {
    final nuevoEstado =
        progress.isCompletedToday ? null : DayStatus.completed;
    await _applyTodayChange(progress, nuevoEstado);
  }

  /// Marca/desmarca el hábito como **complicado** (no cumplido) hoy.
  ///
  /// Si hoy estaba marcado como completado, pasa a complicado.
  Future<void> toggleDifficultToday(HabitProgress progress) async {
    final nuevoEstado =
        progress.isDifficultToday ? null : DayStatus.difficult;
    await _applyTodayChange(progress, nuevoEstado);
  }

  /// Aplica el cambio de estado del día de hoy: primero actualiza la UI
  /// de forma optimista (respuesta inmediata) y luego persiste en la
  /// base de datos; si la escritura falla, revierte el cambio.
  Future<void> _applyTodayChange(
    HabitProgress progress,
    DayStatus? nuevoEstado,
  ) async {
    final habitId = progress.habit.id;
    if (habitId == null) return; // sin id aún no existe en la BD.

    final today = DateTime.now();
    final estadoAnterior = progress.statusOn(today);

    // 1. Actualización optimista en memoria.
    progress.setStatus(today, nuevoEstado);
    notifyListeners();

    // 2. Persistencia; si falla, se revierte.
    try {
      if (nuevoEstado == null) {
        await _db.clearDayEntry(habitId, today);
      } else {
        await _db.setDayEntry(habitId, today, nuevoEstado);
      }
    } catch (e) {
      progress.setStatus(today, estadoAnterior);
      errorMessage = 'No se pudo guardar el cambio: $e';
      notifyListeners();
    }
  }

  /// Elimina un hábito junto con todo su historial.
  Future<void> deleteHabit(HabitProgress progress) async {
    final habitId = progress.habit.id;
    if (habitId == null) return;

    try {
      await _db.deleteHabit(habitId);
      await loadHabits(silent: true);
    } catch (e) {
      errorMessage = 'No se pudo eliminar el hábito: $e';
      notifyListeners();
    }
  }
}
