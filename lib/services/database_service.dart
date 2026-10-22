import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/day_status.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';

/// Servicio de acceso a la base de datos local (SQLite a través de sqflite).
///
/// Implementa el patrón singleton para garantizar una única conexión a la
/// base de datos durante toda la vida de la aplicación.
class DatabaseService {
  DatabaseService._privateConstructor();

  /// Instancia única del servicio.
  static final DatabaseService instance = DatabaseService._privateConstructor();

  static const String _dbName = 'habit_track.db';

  /// v2: la tabla `completions` añade la columna `status` para distinguir
  /// días completados de días complicados.
  static const int _dbVersion = 2;

  static Database? _database;

  /// Devuelve la base de datos, abriéndola (y creándola) si es necesario.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, _dbName);

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crea las tablas la primera vez que se abre la base de datos.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL
      )
    ''');

    // La restricción UNIQUE(habitId, date) garantiza un único registro por
    // hábito y día; la columna `status` guarda el estado de ese día.
    await db.execute('''
      CREATE TABLE completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'completed',
        UNIQUE(habitId, date)
      )
    ''');
  }

  /// Migraciones entre versiones.
  ///
  /// v1 → v2: añade `status` a `completions`. Los registros existentes se
  /// conservan con el valor por defecto ('completed'), que era el único
  /// estado posible en la versión 1.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE completions "
        "ADD COLUMN status TEXT NOT NULL DEFAULT 'completed'",
      );
    }
  }

  // -------------------------------------------------------------------
  // Hábitos
  // -------------------------------------------------------------------

  /// Inserta un hábito nuevo y devuelve el id autogenerado.
  Future<int> insertHabit(Habit habit) async {
    final db = await database;
    return db.insert(
      'habits',
      habit.toMap()..remove('id'), // sin id: lo genera la base de datos
    );
  }

  /// Devuelve todos los hábitos, del más reciente al más antiguo.
  Future<List<Habit>> getHabits() async {
    final db = await database;
    final rows = await db.query('habits', orderBy: 'createdAt DESC');
    return rows.map(Habit.fromMap).toList();
  }

  /// Actualiza el nombre y la descripción de un hábito existente.
  Future<void> updateHabit(Habit habit) async {
    final db = await database;
    await db.update(
      'habits',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  /// Elimina un hábito y todo su historial de cumplimientos.
  ///
  /// Se usa una transacción para que ambas eliminaciones se realicen
  /// (o fallen) de forma atómica.
  Future<void> deleteHabit(int habitId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'completions',
        where: 'habitId = ?',
        whereArgs: [habitId],
      );
      await txn.delete(
        'habits',
        where: 'id = ?',
        whereArgs: [habitId],
      );
    });
  }

  // -------------------------------------------------------------------
  // Registros diarios
  // -------------------------------------------------------------------

  /// Devuelve todos los registros diarios (historial completo).
  Future<List<HabitCompletion>> getAllCompletions() async {
    final db = await database;
    final rows = await db.query('completions');
    return rows.map(HabitCompletion.fromMap).toList();
  }

  /// Guarda el estado de un hábito en un día concreto (completado o
  /// complicado).
  ///
  /// Si ya existía un registro para ese día, se sustituye: el conflicto
  /// con la restricción UNIQUE(habitId, date) convierte la inserción en
  /// un "upsert".
  Future<void> setDayEntry(int habitId, DateTime day, DayStatus status) async {
    final db = await database;
    final entry = HabitCompletion(
      habitId: habitId,
      date: day,
      status: status,
    );
    await db.insert(
      'completions',
      entry.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Elimina el registro de un día (vuelve al estado "sin marcar").
  Future<void> clearDayEntry(int habitId, DateTime day) async {
    final db = await database;
    await db.delete(
      'completions',
      where: 'habitId = ? AND date = ?',
      whereArgs: [habitId, HabitCompletion.formatDate(day)],
    );
  }
}
