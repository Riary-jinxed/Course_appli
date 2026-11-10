import 'package:course_appli/models/run.dart';
import 'package:course_appli/services/run_repository.dart';
import 'package:course_appli/training/models.dart';
import 'package:course_appli/training/plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await databaseFactory.deleteDatabase('${await getDatabasesPath()}/course.db');
  });

  Run run(DateTime at, double km) => Run(
        startedAt: at,
        movingTime: Duration(minutes: (km * 6).round()),
        distanceM: km * 1000,
        elevationGainM: 0,
        elevationLossM: 0,
        calories: 0,
        steps: 0,
        maxSpeedMps: 3,
        points: [
          TrackPoint(time: at, lat: 48.85, lng: 2.35),
          TrackPoint(time: at.add(const Duration(minutes: 1)), lat: 48.851, lng: 2.35),
        ],
      );

  test('créer un objectif génère un programme, une course valide la séance du jour', () async {
    final runs = RunRepository();
    final plans = PlanRepository(runs);
    final now = DateTime.now();
    final goalId = await plans.createGoal(RaceGoal(
      name: '10 km',
      distanceKm: 10,
      date: now.add(const Duration(days: 60)),
      sessionsPerWeek: 3,
      createdAt: now,
    ));
    final sessions = await plans.sessions(goalId);
    expect(sessions.length, greaterThan(10));
    expect(sessions.last.type, SessionType.race);

    final first = sessions.first;
    final r = run(DateTime(first.date.year, first.date.month, first.date.day, 18), 5);
    final runId = await runs.save(r);
    final matched = await plans.matchRun(runId, r);
    expect(matched?.id, first.id);
    final after = await plans.sessions(goalId);
    expect(after.first.done, isTrue);
    expect(after.first.runId, runId);

    // Supprimer la course garde la séance faite mais oublie le lien.
    await runs.delete(runId);
    final afterDelete = await plans.sessions(goalId);
    expect(afterDelete.first.runId, isNull);

    // Validation manuelle puis annulation.
    await plans.setSessionDone(after[1].id!, true);
    expect((await plans.sessions(goalId))[1].done, isTrue);
    await plans.setSessionDone(after[1].id!, false);
    expect((await plans.sessions(goalId))[1].done, isFalse);

    await plans.deleteGoal(goalId);
    expect(await plans.goals(), isEmpty);
  });

  test('migration v1 → v2 : les courses existantes sont conservées', () async {
    final path = '${await getDatabasesPath()}/course.db';
    final v1 = await openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE runs(id INTEGER PRIMARY KEY AUTOINCREMENT, started_at INTEGER NOT NULL, '
          'moving_ms INTEGER NOT NULL, distance_m REAL NOT NULL, elev_gain_m REAL NOT NULL, '
          'elev_loss_m REAL NOT NULL, calories REAL NOT NULL, steps INTEGER NOT NULL, max_speed_mps REAL NOT NULL)');
      await db.execute('CREATE TABLE points(run_id INTEGER NOT NULL, time INTEGER NOT NULL, lat REAL NOT NULL, '
          'lng REAL NOT NULL, altitude REAL, accuracy REAL, speed REAL)');
      await db.execute('CREATE TABLE checkpoints(run_id INTEGER NOT NULL, time INTEGER NOT NULL, lat REAL NOT NULL, '
          'lng REAL NOT NULL, distance_m REAL NOT NULL, elapsed_ms INTEGER NOT NULL, label TEXT)');
      await db.insert('runs', run(DateTime(2026, 11, 1), 8).toMap());
    });
    await v1.close();

    final runs = RunRepository();
    expect((await runs.list()).single.distanceM, 8000);
    expect(await PlanRepository(runs).goals(), isEmpty);
  });
}
