import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../training/plan_repository.dart';
import 'meal_planner.dart';
import 'models.dart';
import 'nutrition_calc.dart';
import 'nutrition_repository.dart';
import 'recipes.dart';
import 'recipes_screen.dart';

/// Planning des repas des 7 prochains jours.
class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  final _today = FoodEntry.dayOf(DateTime.now());
  Map<DateTime, Map<MealType, Recipe>> _plan = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await context.read<NutritionRepository>().mealPlan(_today, 7);
    if (mounted) setState(() => _plan = p);
  }

  Future<void> _generate() async {
    final repo = context.read<NutritionRepository>();
    final profile = context.read<ProfileState>().profile!;
    final goals = await context.read<PlanRepository>().goals();
    final settings = await repo.settings();
    final upcoming = goals.where((g) => !g.date.isBefore(_today)).toList();
    // On compte une course moyenne de 400 kcal un jour sur deux.
    final kcal = NutritionCalc.dailyTarget(profile, settings.activity, settings.goal, runKcal: 200);
    final plan = MealPlanner.plan(
      start: _today,
      dailyKcal: kcal,
      raceDay: upcoming.isEmpty ? null : upcoming.first.date,
      raceKm: upcoming.isEmpty ? 0 : upcoming.first.distanceKm,
    );
    await repo.savePlan(plan);
    _load();
  }

  Future<void> _change(DateTime day, MealType meal) async {
    final repo = context.read<NutritionRepository>();
    final tag = switch (meal) {
      MealType.breakfast => RecipeTag.breakfast,
      MealType.snack => RecipeTag.snack,
      _ => RecipeTag.main,
    };
    final r = await showModalBottomSheet<Recipe>(
      context: context,
      builder: (c) => ListView(children: [
        for (final r in recipes.where((r) => r.tags.contains(tag)))
          ListTile(title: Text(r.name), subtitle: Text('${r.kcal.round()} kcal'), onTap: () => Navigator.pop(c, r)),
      ]),
    );
    if (r == null) return;
    await repo.setPlanned(day, meal, r);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planning repas')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.auto_awesome),
        label: Text(_plan.isEmpty ? 'Générer ma semaine' : 'Regénérer'),
        onPressed: _generate,
      ),
      body: _plan.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Je te propose des repas pour 7 jours, adaptés à ton objectif calorique. '
                  'Si une épreuve approche, la veille et le jour J sont adaptés automatiquement.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(padding: const EdgeInsets.only(bottom: 96), children: [
              for (var i = 0; i < 7; i++)
                () {
                  final day = DateTime(_today.year, _today.month, _today.day + i);
                  final meals = _plan[day] ?? {};
                  final total = meals.values.fold<double>(0, (s, r) => s + r.kcal);
                  return Card(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ListTile(
                        title: Text(DateFormat('EEEE d MMMM', 'fr_FR').format(day),
                            style: Theme.of(context).textTheme.titleMedium),
                        trailing: Text('${total.round()} kcal'),
                      ),
                      for (final m in MealType.values)
                        ListTile(
                          dense: true,
                          leading: Text(m.label.substring(0, 3), style: Theme.of(context).textTheme.labelSmall),
                          title: Text(meals[m]?.name ?? '—'),
                          subtitle: meals[m] == null ? null : Text('${meals[m]!.kcal.round()} kcal'),
                          trailing: IconButton(icon: const Icon(Icons.swap_horiz), onPressed: () => _change(day, m)),
                          onTap: meals[m] == null
                              ? null
                              : () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: meals[m]!))),
                        ),
                    ]),
                  );
                }(),
            ]),
    );
  }
}
