import 'package:course_appli/models/user_profile.dart';
import 'package:course_appli/nutrition/meal_planner.dart';
import 'package:course_appli/nutrition/models.dart';
import 'package:course_appli/nutrition/nutrition_calc.dart';
import 'package:course_appli/nutrition/recipes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();
  final p = UserProfile(weightKg: 70, heightCm: 175, sex: Sex.male, birthDate: DateTime(now.year - 30, 1, 1));

  test('métabolisme de base (Mifflin-St Jeor)', () {
    // 10×70 + 6,25×175 − 5×30 + 5 = 1648,75
    expect(NutritionCalc.bmr(p), closeTo(1648.75, 0.01));
  });

  test('objectif du jour : les courses sont ajoutées, déficit plafonné en perte', () {
    final base = NutritionCalc.baseline(p, ActivityLevel.standing);
    expect(NutritionCalc.dailyTarget(p, ActivityLevel.standing, WeightGoal.maintain, runKcal: 600), closeTo(base + 600, 0.01));
    final lose = NutritionCalc.dailyTarget(p, ActivityLevel.standing, WeightGoal.lose);
    expect(base - lose, closeTo(base * 0.15, 0.01));
    expect(base - lose, lessThanOrEqualTo(500));
  });

  test('macros cohérentes avec les calories', () {
    final m = NutritionCalc.macros(p, 2500, WeightGoal.maintain);
    expect(m.proteinG, 112);
    expect(m.carbsG * 4 + m.proteinG * 4 + m.fatG * 9, closeTo(2500, 1));
  });

  test('conseils course : recharge glucides pour un semi, rien à J-10', () {
    expect(RaceNutrition.advice(daysBefore: 2, raceKm: 21.1, weightKg: 70), contains('560 g'));
    expect(RaceNutrition.advice(daysBefore: 0, raceKm: 10, weightKg: 70), contains('Jour J'));
    expect(RaceNutrition.advice(daysBefore: 10, raceKm: 42, weightKg: 70), isNull);
  });

  test('toutes les recettes ont des valeurs cohérentes', () {
    final ids = <String>{};
    for (final r in recipes) {
      expect(ids.add(r.id), isTrue, reason: 'id en double : ${r.id}');
      final fromMacros = r.carbs * 4 + r.protein * 4 + r.fat * 9;
      expect((fromMacros - r.kcal).abs() / r.kcal, lessThan(0.12), reason: r.name);
    }
    for (final q in quickFoods) {
      expect(q.kcal, greaterThan(0));
    }
  });

  test('planning : 7 jours complets, recharge la veille de l\'épreuve, avant-course le jour J', () {
    final start = DateTime(2026, 11, 9);
    final plan = MealPlanner.plan(start: start, dailyKcal: 2400, raceDay: DateTime(2026, 11, 15), raceKm: 21.1);
    expect(plan.length, 7);
    for (final day in plan.values) {
      expect(day.keys.toSet(), MealType.values.toSet());
      // Pas deux fois la même recette dans la journée.
      expect(day.values.map((r) => r.id).toSet().length, day.length);
    }
    final eve = plan[DateTime(2026, 11, 14)]!;
    expect(eve[MealType.dinner]!.tags, contains(RecipeTag.carbLoad));
    final raceDay = plan[DateTime(2026, 11, 15)]!;
    expect(raceDay[MealType.breakfast]!.tags, contains(RecipeTag.preRace));
    // Les petits-déjeuners varient sur la semaine.
    expect(plan.values.map((d) => d[MealType.breakfast]!.id).toSet().length, greaterThan(1));
  });
}
