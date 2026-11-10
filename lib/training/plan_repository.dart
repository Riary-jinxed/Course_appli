import '../models/run.dart';
import '../services/run_repository.dart';
import 'models.dart';
import 'plan_generator.dart';

class PlanRepository {
  final RunRepository runs;
  PlanRepository(this.runs);

  Future<List<RaceGoal>> goals() async {
    final db = await runs.database;
    final rows = await db.query('goals', orderBy: 'date');
    return rows.map(RaceGoal.fromMap).toList();
  }

  Future<List<PlannedSession>> sessions(int goalId) async {
    final db = await runs.database;
    final rows =
        await db.query('sessions', where: 'goal_id = ?', whereArgs: [goalId], orderBy: 'date');
    return rows.map(PlannedSession.fromMap).toList();
  }

  /// Volume moyen hebdo sur les 4 dernières semaines, pour calibrer le programme.
  Future<double> recentWeeklyKm() async {
    final since = DateTime.now().subtract(const Duration(days: 28));
    final all = await runs.list();
    final km = all
        .where((r) => r.startedAt.isAfter(since))
        .fold<double>(0, (s, r) => s + r.distanceM / 1000);
    return km / 4;
  }

  /// Crée l'objectif et son programme.
  Future<int> createGoal(RaceGoal goal) async {
    final weekly = await recentWeeklyKm();
    final plan = PlanGenerator.generate(goal: goal, start: DateTime.now(), currentWeeklyKm: weekly);
    final db = await runs.database;
    return db.transaction((txn) async {
      final id = await txn.insert('goals', goal.toMap());
      final b = txn.batch();
      for (final s in plan) {
        b.insert('sessions', s.toMap(id));
      }
      await b.commit(noResult: true);
      return id;
    });
  }

  Future<void> deleteGoal(int id) async {
    final db = await runs.database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setSessionDone(int sessionId, bool done, {int? runId}) async {
    final db = await runs.database;
    await db.update('sessions', {'done': done ? 1 : 0, 'run_id': done ? runId : null},
        where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Après une course : valide la séance prévue le même jour (ou la veille / le
  /// lendemain si aucune ce jour-là) encore non faite.
  Future<PlannedSession?> matchRun(int runId, Run run) async {
    final db = await runs.database;
    final day = DateTime(run.startedAt.year, run.startedAt.month, run.startedAt.day);
    for (final offset in [0, -1, 1]) {
      final from = day.add(Duration(days: offset));
      final to = from.add(const Duration(days: 1));
      final rows = await db.query(
        'sessions',
        where: 'done = 0 AND date >= ? AND date < ?',
        whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final s = PlannedSession.fromMap(rows.first);
        await setSessionDone(s.id!, true, runId: runId);
        return s;
      }
    }
    return null;
  }
}
