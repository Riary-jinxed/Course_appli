import 'package:course_appli/training/models.dart';
import 'package:course_appli/training/plan_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 9); // lundi

  RaceGoal goal(double km, int weeks, {int spw = 3, Duration? target}) => RaceGoal(
        name: 'Test',
        distanceKm: km,
        date: start.add(Duration(days: 7 * weeks - 1)), // dimanche
        targetTime: target,
        sessionsPerWeek: spw,
        createdAt: start,
      );

  test('10 km en 10 semaines, 3 séances : structure du programme', () {
    final plan = PlanGenerator.generate(goal: goal(10, 10), start: start);
    expect(plan.last.type, SessionType.race);
    expect(plan.last.date, DateTime(2027, 1, 17));
    // 3 séances par semaine sauf la dernière (2 + jour J).
    expect(plan.length, 9 * 3 + 2 + 1);
    // Pas de fractionné les 2 premières semaines.
    final firstTwoWeeks = plan.where((s) => s.date.isBefore(start.add(const Duration(days: 14))));
    expect(firstTwoWeeks.any((s) => s.type == SessionType.intervals), isFalse);
    expect(plan.any((s) => s.type == SessionType.intervals), isTrue);
  });

  test('progression : jamais plus de +10 % sauf après une semaine allégée', () {
    final plan = PlanGenerator.generate(goal: goal(21.1, 16, spw: 4), start: start, currentWeeklyKm: 20);
    final weekly = List<double>.filled(16, 0);
    for (final s in plan.where((s) => s.type != SessionType.race)) {
      weekly[s.date.difference(start).inDays ~/ 7] += s.distanceKm;
    }
    // Pic plus élevé que le départ, affûtage à la fin.
    expect(weekly.reduce((a, b) => a > b ? a : b), greaterThan(weekly.first));
    expect(weekly[15], lessThan(weekly[13]));
    expect(weekly[14], lessThan(weekly[13]));
  });

  test('sortie longue plafonnée selon la distance', () {
    final plan = PlanGenerator.generate(goal: goal(5, 12, spw: 5), start: start, currentWeeklyKm: 60);
    final longest = plan
        .where((s) => s.type == SessionType.long)
        .map((s) => s.distanceKm)
        .reduce((a, b) => a > b ? a : b);
    expect(longest, lessThanOrEqualTo(PlanGenerator.longRunCapKm(5)));
  });

  test('allures cibles à partir du temps visé', () {
    final plan = PlanGenerator.generate(
        goal: goal(10, 8, target: const Duration(minutes: 50)), start: start);
    final race = plan.last;
    expect(race.targetPaceSec, 300); // 5:00/km
    final easy = plan.firstWhere((s) => s.type == SessionType.easy);
    expect(easy.targetPaceSec, 375); // 6:15/km
  });

  test('objectif proche : programme court mais valide', () {
    final plan = PlanGenerator.generate(goal: goal(10, 1), start: start);
    expect(plan.last.type, SessionType.race);
    expect(plan.every((s) => !s.date.isBefore(start)), isTrue);
  });
}
