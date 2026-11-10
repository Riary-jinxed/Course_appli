import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/run.dart';

/// Stockage local des courses (fonctionne hors ligne).
class RunRepository {
  Database? _db;

  Future<Database> get _database async {
    return _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'course.db'),
      version: 1,
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
      },
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<int> save(Run run) async {
    final db = await _database;
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
    final db = await _database;
    final rows = await db.query('runs', orderBy: 'started_at DESC');
    return rows.map(Run.fromMap).toList();
  }

  Future<Run?> get(int id) async {
    final db = await _database;
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
    final db = await _database;
    await db.delete('runs', where: 'id = ?', whereArgs: [id]);
  }
}
