/// Modelo que representa un hábito creado por el usuario.
class Habit {
  final int? id;
  final String name;
  final String description;
  final DateTime createdAt;

  const Habit({
    this.id,
    required this.name,
    required this.description,
    required this.createdAt,
  });

  /// Convierte el modelo a un mapa para insertarlo en sqflite.
  ///
  /// El `id` se excluye al insertar (null) para que la base de datos lo
  /// genere automáticamente; por eso se usa `Object?` como tipo de valor.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Crea un [Habit] a partir de una fila de la base de datos.
  factory Habit.fromMap(Map<String, Object?> map) {
    return Habit(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Devuelve una copia del hábito con los campos indicados modificados.
  /// Se usa al editar el nombre o la descripción.
  Habit copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
