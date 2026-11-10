import 'dart:math';

import 'models.dart';

/// Génère un programme de préparation progressif vers une épreuve.
///
/// Principes :
/// - le volume hebdo part du niveau actuel et augmente d'au plus 10 % par semaine ;
/// - une semaine sur quatre est allégée (-25 %) pour récupérer ;
/// - la sortie longue progresse jusqu'à un plafond adapté à la distance ;
/// - les deux dernières semaines sont un affûtage (volume réduit, intensité gardée) ;
/// - les séances de qualité (fractionné, seuil) arrivent après 2 semaines de base.
class PlanGenerator {
  /// Jours d'entraînement (1 = lundi … 7 = dimanche) selon le nombre de séances.
  static const _days = {
    2: [3, 7],
    3: [2, 4, 7],
    4: [2, 3, 5, 7],
    5: [1, 2, 4, 5, 7],
    6: [1, 2, 3, 4, 5, 7],
  };

  /// Plafond de la sortie longue selon la distance de l'épreuve.
  static double longRunCapKm(double raceKm) {
    if (raceKm <= 5) return 8;
    if (raceKm <= 10) return 14;
    if (raceKm <= 21.1) return 20;
    if (raceKm <= 42.2) return 32;
    return min(raceKm * 0.6, 45);
  }

  /// Volume hebdo visé au pic de la préparation.
  static double peakWeeklyKm(double raceKm, int sessionsPerWeek) {
    final base = raceKm <= 5
        ? 25.0
        : raceKm <= 10
            ? 35.0
            : raceKm <= 21.1
                ? 45.0
                : 60.0;
    return base * (0.6 + 0.1 * sessionsPerWeek).clamp(0.8, 1.2);
  }

  /// [currentWeeklyKm] : volume moyen des dernières semaines (0 si débutant).
  static List<PlannedSession> generate({
    required RaceGoal goal,
    required DateTime start,
    double currentWeeklyKm = 0,
  }) {
    final spw = goal.sessionsPerWeek.clamp(2, 6);
    final days = _days[spw]!;
    final startDay = DateTime(start.year, start.month, start.day);
    final raceDay = DateTime(goal.date.year, goal.date.month, goal.date.day);
    // Lundi de la semaine de départ.
    final firstMonday = _addDays(startDay, 1 - startDay.weekday);
    final weeks = max(1, (raceDay.difference(firstMonday).inDays / 7).ceil());

    final peak = peakWeeklyKm(goal.distanceKm, spw);
    final startVolume = max(currentWeeklyKm, min(peak * 0.5, spw * 4.0));
    final longCap = longRunCapKm(goal.distanceKm);
    final pace = goal.racePaceSecPerKm;

    final sessions = <PlannedSession>[];
    var volume = startVolume;
    for (var w = 0; w < weeks; w++) {
      final weeksLeft = weeks - w; // 1 = semaine de l'épreuve
      final isRaceWeek = weeksLeft == 1;
      final isTaper = weeksLeft == 2;
      final isDeload = !isRaceWeek && !isTaper && w > 0 && (w + 1) % 4 == 0;

      if (w > 0 && !isDeload) volume = min(volume * 1.1, peak);
      var weekVolume = volume;
      if (isDeload) weekVolume *= 0.75;
      if (isTaper) weekVolume *= 0.7;
      if (isRaceWeek) weekVolume *= 0.4;

      final quality = w >= 2 && !isDeload;
      final monday = _addDays(firstMonday, 7 * w);

      // Répartition : la sortie longue prend ~35 %, le reste est partagé.
      final longKm = min(longCap, weekVolume * 0.35);
      final otherKm = (weekVolume - longKm) / max(1, spw - 1);

      for (final (i, wd) in days.indexed) {
        final date = _addDays(monday, wd - 1);
        if (date.isBefore(startDay)) continue;
        if (!date.isBefore(raceDay)) break;
        final isLast = i == days.length - 1;
        SessionType type;
        double km;
        if (isLast && !isRaceWeek) {
          type = SessionType.long;
          km = longKm;
        } else if (quality && i == 0) {
          type = SessionType.intervals;
          km = otherKm;
        } else if (quality && spw >= 4 && i == 2) {
          type = SessionType.tempo;
          km = otherKm;
        } else {
          type = SessionType.easy;
          km = isRaceWeek ? min(otherKm, 6) : otherKm;
        }
        final minKm = type == SessionType.intervals || type == SessionType.tempo ? 6.0 : 3.0;
        km = _round(max(km, minKm));
        sessions.add(PlannedSession(
          date: date,
          type: type,
          distanceKm: km,
          targetPaceSec: pace == null ? null : _paceFor(type, pace).round(),
          description: _describe(type, km, pace, goal.distanceKm),
        ));
      }
    }

    sessions.add(PlannedSession(
      date: raceDay,
      type: SessionType.race,
      distanceKm: goal.distanceKm,
      targetPaceSec: pace?.round(),
      description: '${goal.name} : donne tout !',
    ));
    return sessions;
  }

  /// Ajout de jours calendaires (sans décalage lors des changements d'heure).
  static DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  static double _round(double km) => (km * 2).round() / 2;

  /// Allure cible par type de séance, à partir de l'allure de course (s/km).
  static double _paceFor(SessionType t, double race) => switch (t) {
        SessionType.easy => race * 1.25,
        SessionType.long => race * 1.2,
        SessionType.tempo => race * 1.03,
        SessionType.intervals => race * 0.95,
        SessionType.race => race,
      };

  static String _fmt(double secPerKm) {
    final s = secPerKm.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}/km';
  }

  static String _km(double km) =>
      km == km.roundToDouble() ? km.toInt().toString() : km.toString().replaceAll('.', ',');

  static String _describe(SessionType t, double kmValue, double? race, double raceKm) {
    final p = race == null ? null : _fmt(_paceFor(t, race));
    final km = _km(kmValue);
    // 2 km d'échauffement + 1 km de retour au calme autour des séances de qualité.
    final work = max(2.0, kmValue - 3);
    switch (t) {
      case SessionType.easy:
        return 'Footing tranquille de $km km${p == null ? ', en aisance respiratoire' : ' vers $p'}.';
      case SessionType.long:
        return 'Sortie longue de $km km, à allure confortable${p == null ? '' : ' (~$p)'}.';
      case SessionType.tempo:
        return '2 km d\'échauffement, ${_km(work)} km à allure seuil${p == null ? '' : ' ($p)'}, 1 km de retour au calme.';
      case SessionType.intervals:
        final repM = raceKm <= 10 ? 400 : 1000;
        final rep = '$repM m';
        final n = (work * 1000 / repM * 0.8).floor().clamp(3, 12);
        return 'Échauffement 2 km, $n×$rep rapide${p == null ? '' : ' ($p)'} avec 1 min 30 de récup trottinée, 1 km de retour au calme.';
      case SessionType.race:
        return 'Jour J.';
    }
  }
}
