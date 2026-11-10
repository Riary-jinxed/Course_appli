import 'dart:math';

import 'package:course_appli/coach/coach_brain.dart';
import 'package:course_appli/models/run.dart';
import 'package:course_appli/shoes/shoes.dart';
import 'package:course_appli/training/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 12, 9); // jeudi
  Run run(int daysAgo, double km, {int minPerKm = 6}) => Run(
        startedAt: DateTime(now.year, now.month, now.day - daysAgo, 18),
        movingTime: Duration(minutes: (km * minPerKm).round()),
        distanceM: km * 1000,
        elevationGainM: 0,
        elevationLossM: 0,
        calories: 0,
        steps: 0,
        maxSpeedMps: 4,
      );

  test('alerte de charge quand la semaine explose', () {
    final runs = [
      run(0, 15), run(1, 12), run(3, 14), // 41 km sur 7 jours
      run(9, 5), run(12, 5), run(16, 5), run(20, 5), run(24, 5),
    ];
    final brain = CoachBrain(CoachSnapshot(now: now, runs: runs));
    expect(brain.s.loadRatio, greaterThan(1.5));
    expect(brain.insights().first, contains('Risque de blessure'));
  });

  test('bilan de la semaine et progression', () {
    final runs = [run(0, 8, minPerKm: 5), run(2, 6, minPerKm: 5), run(8, 10, minPerKm: 6), run(10, 10, minPerKm: 6)];
    final brain = CoachBrain(CoachSnapshot(now: now, runs: runs), random: Random(1));
    expect(brain.answer('bilan de la semaine ?'), contains('2 courses, 14,0 km'));
    final p = brain.answer('est-ce que je progresse ?');
    expect(p, contains('5:00/km'));
    expect(p, contains('progression'));
  });

  test('séance du jour, chaussures usées et inactivité dans l\'accueil', () {
    final brain = CoachBrain(CoachSnapshot(
      now: now,
      name: 'Roitel',
      runs: [run(6, 5)],
      upcoming: [
        PlannedSession(date: DateTime(2026, 11, 13), type: SessionType.easy, distanceKm: 6, description: 'Footing 6 km'),
      ],
      shoes: [Shoe(name: 'Pegasus', createdAt: now, km: 720, maxKm: 700)],
    ));
    final g = brain.greeting();
    expect(g, contains('Roitel'));
    expect(g, contains('Pas de course depuis 6 jours'));
    expect(g, contains('Pegasus'));
    expect(brain.answer('ma prochaine séance'), contains('demain'));
  });

  test('question inconnue : aide', () {
    final brain = CoachBrain(CoachSnapshot(now: now));
    expect(brain.answer('quel est le sens de la vie'), contains('Je peux te parler'));
    expect(brain.answer('combien de calories il me reste'), contains('Nutrition'));
  });
}
