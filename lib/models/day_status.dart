/// Estado posible de un hábito en un día concreto.
enum DayStatus {
  /// El hábito se cumplió ese día.
  completed('completed', 'Completado'),

  /// El hábito no se pudo cumplir (día complicado / incompleto).
  difficult('difficult', 'Complicado');

  const DayStatus(this.value, this.label);

  /// Valor persistido en la columna `status` de la base de datos.
  final String value;

  /// Etiqueta visible en la interfaz.
  final String label;

  /// Reconstruye el enum desde el valor almacenado.
  ///
  /// Las filas anteriores a la migración v2 no tienen valor; se asume
  /// [DayStatus.completed], que era el único estado posible entonces.
  static DayStatus fromValue(String? value) =>
      value == DayStatus.difficult.value
          ? DayStatus.difficult
          : DayStatus.completed;
}
