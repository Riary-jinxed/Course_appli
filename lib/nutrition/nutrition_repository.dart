import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../services/run_repository.dart';
import 'models.dart';
import 'nutrition_calc.dart';
import 'recipes.dart';

class NutritionSettings {
  final ActivityLevel activity;
  final WeightGoal goal;
  const NutritionSettings({this.activity = ActivityLevel.standing, this.goal = WeightGoal.maintain});
}

/// Journal alimentaire, eau et planning de repas (stockés sur le téléphone).
class NutritionRepository {
  final RunRepository runs;
  NutritionRepository(this.runs);

  Future<Database> get _db => runs.database;
  int _day(DateTime d) => FoodEntry.dayOf(d).millisecondsSinceEpoch;

  Future<NutritionSettings> settings() async {
    final p = await SharedPreferences.getInstance();
    return NutritionSettings(
      activity: ActivityLevel.values.firstWhere((a) => a.name == p.getString('nutri_activity'),
          orElse: () => ActivityLevel.standing),
      goal: WeightGoal.values.firstWhere((g) => g.name == p.getString('nutri_goal'),
          orElse: () => WeightGoal.maintain),
    );
  }

  Future<void> saveSettings(NutritionSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('nutri_activity', s.activity.name);
    await p.setString('nutri_goal', s.goal.name);
  }

  Future<List<FoodEntry>> entries(DateTime day) async {
    final rows = await (await _db).query('food_entries', where: 'day = ?', whereArgs: [_day(day)], orderBy: 'id');
    return rows.map(FoodEntry.fromMap).toList();
  }

  Future<int> add(FoodEntry e) async => (await _db).insert('food_entries', e.toMap());

  Future<void> remove(int id) async => (await _db).delete('food_entries', where: 'id = ?', whereArgs: [id]);

  Future<int> water(DateTime day) async {
    final rows = await (await _db).query('water', where: 'day = ?', whereArgs: [_day(day)]);
    return rows.isEmpty ? 0 : rows.first['ml'] as int;
  }

  Future<void> setWater(DateTime day, int ml) async => (await _db).insert(
      'water', {'day': _day(day), 'ml': ml < 0 ? 0 : ml},
      conflictAlgorithm: ConflictAlgorithm.replace);

  /// Calories et durée des courses du jour.
  Future<(double, Duration)> runsOf(DateTime day) async {
    final from = FoodEntry.dayOf(day);
    final to = DateTime(from.year, from.month, from.day + 1);
    final all = await runs.list();
    final today = all.where((r) => !r.startedAt.isBefore(from) && r.startedAt.isBefore(to));
    return (
      today.fold<double>(0, (s, r) => s + r.calories),
      today.fold<Duration>(Duration.zero, (s, r) => s + r.movingTime),
    );
  }

  // --- Planning ------------------------------------------------------------

  Future<Map<DateTime, Map<MealType, Recipe>>> mealPlan(DateTime from, int days) async {
    final to = DateTime(from.year, from.month, from.day + days);
    final rows = await (await _db).query('meal_plan',
        where: 'day >= ? AND day < ?', whereArgs: [_day(from), to.millisecondsSinceEpoch], orderBy: 'day');
    final out = <DateTime, Map<MealType, Recipe>>{};
    for (final r in rows) {
      final recipe = recipeById(r['recipe_id'] as String?);
      if (recipe == null) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(r['day'] as int);
      out.putIfAbsent(d, () => {})[MealType.values.byName(r['meal'] as String)] = recipe;
    }
    return out;
  }

  Future<void> savePlan(Map<DateTime, Map<MealType, Recipe>> plan) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final e in plan.entries) {
        for (final m in e.value.entries) {
          await txn.insert('meal_plan', {'day': _day(e.key), 'meal': m.key.name, 'recipe_id': m.value.id},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> setPlanned(DateTime day, MealType meal, Recipe r) => savePlan({
        day: {meal: r}
      });

  /// Recettes favorites (identifiants).
  Future<Set<String>> favorites() async {
    final p = await SharedPreferences.getInstance();
    return (jsonDecode(p.getString('nutri_fav') ?? '[]') as List).cast<String>().toSet();
  }

  Future<void> toggleFavorite(String id) async {
    final f = await favorites();
    f.contains(id) ? f.remove(id) : f.add(id);
    final p = await SharedPreferences.getInstance();
    await p.setString('nutri_fav', jsonEncode(f.toList()));
  }
}
