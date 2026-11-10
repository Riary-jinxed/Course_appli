import '../models/run.dart';
import '../services/geo.dart';
import '../services/run_repository.dart';
import 'best_efforts.dart';

class RecordsRepository {
  final RunRepository runs;
  RecordsRepository(this.runs);

  /// Meilleur temps actuel par distance (hors course [exceptRunId]).
  Future<Map<int, double>> bests({int? exceptRunId}) async {
    final db = await runs.database;
    final rows = await db.rawQuery(
      'SELECT distance_m, MIN(seconds) AS s FROM run_bests ${exceptRunId == null ? '' : 'WHERE run_id != ?'} GROUP BY distance_m',
      [?exceptRunId],
    );
    return {for (final r in rows) r['distance_m'] as int: (r['s'] as num).toDouble()};
  }

  /// Calcule et enregistre les meilleurs temps d'une course.
  /// Renvoie les records battus (ex. ["5 km"]).
  Future<List<String>> process(int runId, Run run) async {
    final previous = await bests(exceptRunId: runId);
    final efforts = bestEfforts(run.points);
    final db = await runs.database;
    await db.transaction((txn) async {
      await txn.delete('run_bests', where: 'run_id = ?', whereArgs: [runId]);
      for (final e in efforts.entries) {
        await txn.insert('run_bests', {'run_id': runId, 'distance_m': e.key, 'seconds': e.value});
      }
      await txn.update('runs', {'bests_done': 1}, where: 'id = ?', whereArgs: [runId]);
    });
    // Pas de "record" pour la toute première course : rien à battre.
    if (previous.isEmpty && (await runs.list()).length <= 1) return [];
    return newRecords(efforts, previous);
  }

  /// Calcule les meilleurs temps des courses qui ne l'ont pas encore été
  /// (anciennes courses, courses restaurées depuis la sauvegarde).
  Future<void> backfill() async {
    final db = await runs.database;
    final rows = await db.query('runs', columns: ['id'], where: 'bests_done = 0');
    for (final r in rows) {
      final run = await runs.get(r['id'] as int);
      if (run != null) await process(run.id!, run);
    }
  }

  /// Tous les records personnels, prêts à afficher.
  Future<List<PersonalRecord>> all() async {
    await backfill();
    final db = await runs.database;
    final out = <PersonalRecord>[];
    for (final e in recordDistances.entries) {
      final rows = await db.rawQuery(
        'SELECT b.seconds, b.run_id, r.started_at FROM run_bests b JOIN runs r ON r.id = b.run_id '
        'WHERE b.distance_m = ? ORDER BY b.seconds LIMIT 1',
        [e.key],
      );
      if (rows.isEmpty) continue;
      final s = (rows.first['seconds'] as num).toDouble();
      out.add(PersonalRecord(
        e.value,
        '${formatDuration(Duration(seconds: s.round()))} · ${formatPace(e.key / s)}/km',
        rows.first['run_id'] as int,
        DateTime.fromMillisecondsSinceEpoch(rows.first['started_at'] as int),
      ));
    }
    final all = await runs.list();
    if (all.isEmpty) return out;
    Run best(int Function(Run, Run) cmp) => all.reduce((a, b) => cmp(a, b) >= 0 ? a : b);
    final longest = best((a, b) => a.distanceM.compareTo(b.distanceM));
    out.add(PersonalRecord('Plus longue sortie', '${(longest.distanceM / 1000).toStringAsFixed(2)} km',
        longest.id, longest.startedAt));
    final longTime = best((a, b) => a.movingTime.compareTo(b.movingTime));
    out.add(PersonalRecord('Plus longue durée', formatDuration(longTime.movingTime), longTime.id, longTime.startedAt));
    final climb = best((a, b) => a.elevationGainM.compareTo(b.elevationGainM));
    if (climb.elevationGainM >= 1) {
      out.add(PersonalRecord('Plus gros D+', '${climb.elevationGainM.round()} m', climb.id, climb.startedAt));
    }
    // Semaine (lundi → dimanche) la plus chargée.
    final weeks = <DateTime, double>{};
    for (final r in all) {
      final d = r.startedAt;
      final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
      weeks[monday] = (weeks[monday] ?? 0) + r.distanceM;
    }
    final topWeek = weeks.entries.reduce((a, b) => a.value >= b.value ? a : b);
    out.add(PersonalRecord('Plus grosse semaine', '${(topWeek.value / 1000).toStringAsFixed(1)} km', null, topWeek.key));
    return out;
  }
}
