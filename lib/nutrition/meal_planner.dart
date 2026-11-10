import 'models.dart';
import 'recipes.dart';

/// Génère un planning de repas sur plusieurs jours à partir des recettes,
/// en visant l'objectif calorique de chaque repas et en évitant les répétitions.
///
/// Autour d'une épreuve : recharge en glucides la veille (et l'avant-veille si
/// semi ou plus), petit-déjeuner "avant course" le jour J.
class MealPlanner {
  static Map<DateTime, Map<MealType, Recipe>> plan({
    required DateTime start,
    int days = 7,
    required double dailyKcal,
    DateTime? raceDay,
    double raceKm = 0,
  }) {
    final result = <DateTime, Map<MealType, Recipe>>{};
    final recent = <String>[]; // dernières recettes utilisées
    final race = raceDay == null ? null : DateTime(raceDay.year, raceDay.month, raceDay.day);

    for (var i = 0; i < days; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      final daysBefore = race?.difference(day).inDays;
      final carbLoad = daysBefore != null && (daysBefore == 1 || (raceKm >= 21 && daysBefore == 2));
      final raceMorning = daysBefore == 0;
      final meals = <MealType, Recipe>{};
      for (final meal in MealType.values) {
        final budget = dailyKcal * meal.share;
        final required = <RecipeTag>{
          switch (meal) {
            MealType.breakfast => RecipeTag.breakfast,
            MealType.snack => RecipeTag.snack,
            _ => RecipeTag.main,
          },
          if (carbLoad) RecipeTag.carbLoad,
          if (raceMorning && meal == MealType.breakfast) RecipeTag.preRace,
          if (raceMorning && meal == MealType.snack) RecipeTag.preRace,
        };
        var pool = recipes.where((r) => r.tags.containsAll(required)).toList();
        if (pool.isEmpty) pool = recipes.where((r) => r.tags.contains(required.first)).toList();
        // Pas la même recette deux fois dans la journée, ni dans les 2 jours précédents si possible.
        final fresh = pool.where((r) => !recent.contains(r.id) && !meals.values.contains(r)).toList();
        final candidates = fresh.isNotEmpty ? fresh : pool;
        candidates.sort((a, b) => (a.kcal - budget).abs().compareTo((b.kcal - budget).abs()));
        // Un peu de variété : on alterne entre les deux plus proches du budget.
        final pick = candidates[candidates.length > 1 ? (i + meal.index) % 2 : 0];
        meals[meal] = pick;
        recent.add(pick.id);
      }
      while (recent.length > 8) {
        recent.removeAt(0);
      }
      result[day] = meals;
    }
    return result;
  }
}
