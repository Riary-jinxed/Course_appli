import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/run.dart';

/// Stockage local des courses (fonctionne hors ligne).
class RunRepository {
  Database? _db;

  /// Base partagée avec les autres dépôts (programmes d'entraînement).
  Future<Database> get database async {
    return _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'course.db'),
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE runs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            moving_ms INTEGER NOT NULL,
            distance_m REAL NOT NULL,
            elev_gain_m REAL NOT NULL,
            elev_loss_m REAL NOT NULL,
            calories REAL NOT NULL,
            steps INTEGER NOT NULL,
            max_speed_mps REAL NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE points(
            run_id INTEGER NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
            time INTEGER NOT NULL, lat REAL NOT NULL, lng REAL NOT NULL,
            altitude REAL, accuracy REAL, speed REAL
          )''');
        await db.execute('''
          CREATE TABLE checkpoints(
            run_id INTEGER NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
            time INTEGER NOT NULL, lat REAL NOT NULL, lng REAL NOT NULL,
            distance_m REAL NOT NULL, elapsed_ms INTEGER NOT NULL, label TEXT
          )''');
        await db.execute('CREATE INDEX idx_points_run ON points(run_id)');
        await _createV2(db);
        await _createV3(db);
      },
      onUpgrade: (db, from, to) async {
        if (from < 2) await _createV2(db);
        if (from < 3) await _createV3(db);
      },
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<int> save(Run run) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('runs', run.toMap());
      final batch = txn.batch();
      for (final pt in run.points) {
        batch.insert('points', pt.toMap(id));
      }
      for (final cp in run.checkpoints) {
        batch.insert('checkpoints', cp.toMap(id));
      }
      await batch.commit(noResult: true);
      return id;
    });
  }

  /// Liste des courses, sans les points GPS (plus léger).
  Future<List<Run>> list() async {
    final db = await database;
    final rows = await db.query('runs', orderBy: 'started_at DESC');
    return rows.map(Run.fromMap).toList();
  }

  Future<Run?> get(int id) async {
    final db = await database;
    final rows = await db.query('runs', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final pts = await db.query('points', where: 'run_id = ?', whereArgs: [id], orderBy: 'time');
    final cps =
        await db.query('checkpoints', where: 'run_id = ?', whereArgs: [id], orderBy: 'time');
    return Run.fromMap(
      rows.first,
      points: pts.map(TrackPoint.fromMap).toList(),
      checkpoints: cps.map(Checkpoint.fromMap).toList(),
    );
  }

  Future<void> delete(int id) async {
    final db = await database;
    await db.delete('runs', where: 'id = ?', whereArgs: [id]);
  }

  /// v2 : objectifs d'événement et séances de programme.
  static Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        distance_km REAL NOT NULL,
        date INTEGER NOT NULL,
        target_s INTEGER,
        sessions_per_week INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
        date INTEGER NOT NULL,
        type TEXT NOT NULL,
        distance_km REAL NOT NULL,
        target_pace_s INTEGER,
        description TEXT NOT NULL,
        run_id INTEGER REFERENCES runs(id) ON DELETE SET NULL,
        done INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('CREATE INDEX idx_sessions_goal ON sessions(goal_id, date)');
  }

  /// v3 : nutrition (journal, eau, planning de repas).
  static Future<void> _createV3(Database db) async {
    await db.execute('''
      CREATE TABLE food_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day INTEGER NOT NULL,
        meal TEXT NOT NULL,
        name TEXT NOT NULL,
        kcal REAL NOT NULL,
        carbs REAL NOT NULL DEFAULT 0,
        protein REAL NOT NULL DEFAULT 0,
        fat REAL NOT NULL DEFAULT 0,
        extra INTEGER NOT NULL DEFAULT 0,
        recipe_id TEXT
      )''');
    await db.execute('CREATE INDEX idx_food_day ON food_entries(day)');
    await db.execute('CREATE TABLE water(day INTEGER PRIMARY KEY, ml INTEGER NOT NULL)');
    await db.execute('''
      CREATE TABLE meal_plan(
        day INTEGER NOT NULL,
        meal TEXT NOT NULL,
        recipe_id TEXT NOT NULL,
        PRIMARY KEY (day, meal)
      )''');
  }
}
