import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/user_profile.dart';
import '../training/models.dart';
import '../training/plan_repository.dart';
import 'add_food_sheet.dart';
import 'meal_plan_screen.dart';
import 'models.dart';
import 'nutrition_calc.dart';
import 'nutrition_repository.dart';
import 'recipes_screen.dart';

/// Onglet Nutrition : bilan du jour, repas, eau, conseils course.
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => NutritionScreenState();
}

class _DayData {
  final NutritionSettings settings;
  final List<FoodEntry> entries;
  final int waterMl;
  final double runKcal;
  final Duration runTime;
  final Map<MealType, Recipe> planned;
  final RaceGoal? nextRace;
  const _DayData(this.settings, this.entries, this.waterMl, this.runKcal, this.runTime, this.planned, this.nextRace);
}

class NutritionScreenState extends State<NutritionScreen> {
  DateTime _day = FoodEntry.dayOf(DateTime.now());
  Future<_DayData>? _data;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    final repo = context.read<NutritionRepository>();
    final plans = context.read<PlanRepository>();
    final day = _day;
    setState(() {
      _data = () async {
        final (runKcal, runTime) = await repo.runsOf(day);
        final plan = await repo.mealPlan(day, 1);
        final goals = await plans.goals();
        final next = goals.where((g) => !FoodEntry.dayOf(g.date).isBefore(day)).firstOrNull;
        return _DayData(await repo.settings(), await repo.entries(day), await repo.water(day), runKcal, runTime,
            plan[day] ?? {}, next);
      }();
    });
  }

  void _shiftDay(int d) {
    _day = DateTime(_day.year, _day.month, _day.day + d);
    reload();
  }

  Future<void> _add(MealType meal, {int tab = 0}) async {
    final repo = context.read<NutritionRepository>();
    final e = await showAddFoodSheet(context, _day, meal, initialTab: tab);
    if (e == null) return;
    await repo.add(e);
    reload();
  }

  Future<void> _settings(NutritionSettings s) async {
    final repo = context.read<NutritionRepository>();
    var activity = s.activity;
    var goal = s.goal;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mon objectif', style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<WeightGoal>(
              segments: [for (final g in WeightGoal.values) ButtonSegment(value: g, label: Text(g.label))],
              selected: {goal},
              onSelectionChanged: (v) => set(() => goal = v.first),
            ),
            const SizedBox(height: 16),
            Text('Activité au quotidien (hors sport)', style: Theme.of(c).textTheme.titleMedium),
            RadioGroup<ActivityLevel>(
              groupValue: activity,
              onChanged: (v) => set(() => activity = v!),
              child: Column(children: [
                for (final a in ActivityLevel.values) RadioListTile<ActivityLevel>(value: a, title: Text(a.label)),
              ]),
            ),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enregistrer')),
          ]),
        ),
      ),
    );
    if (ok == true) {
      await repo.saveSettings(NutritionSettings(activity: activity, goal: goal));
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileState>().profile ?? const UserProfile();
    final isToday = _day == FoodEntry.dayOf(DateTime.now());
    return FutureBuilder<_DayData>(
      future: _data,
      builder: (context, snap) {
        final d = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Nutrition'),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu_book),
                tooltip: 'Idées recettes',
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipesScreen()));
                  reload();
                },
              ),
              IconButton(
                icon: const Icon(Icons.calendar_view_week),
                tooltip: 'Planning repas',
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPlanScreen()));
                  reload();
                },
              ),
              if (d != null)
                IconButton(icon: const Icon(Icons.tune), tooltip: 'Objectif', onPressed: () => _settings(d.settings)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'extra',
            icon: const Text('🍪', style: TextStyle(fontSize: 20)),
            label: const Text('Grignotage / extra'),
            onPressed: () => _add(MealType.snack, tab: 1),
          ),
          body: d == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.only(bottom: 96), children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftDay(-1)),
                    Text(isToday ? "Aujourd'hui" : DateFormat('EEEE d MMMM', 'fr_FR').format(_day),
                        style: Theme.of(context).textTheme.titleMedium),
                    IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shiftDay(1)),
                  ]),
                  _Summary(profile: profile, data: d),
                  _RaceAdvice(profile: profile, data: d, day: _day),
                  _Water(
                    ml: d.waterMl,
                    target: NutritionCalc.waterMl(profile, running: d.runTime),
                    onChange: (ml) async {
                      await context.read<NutritionRepository>().setWater(_day, ml);
                      reload();
                    },
                  ),
                  for (final m in MealType.values)
                    _MealSection(
                      meal: m,
                      entries: d.entries.where((e) => e.meal == m).toList(),
                      planned: d.planned[m],
                      onAdd: () => _add(m),
                      onAddPlanned: (r) async {
                        await context.read<NutritionRepository>().add(FoodEntry.fromRecipe(r, _day, m));
                        reload();
                      },
                      onDelete: (e) async {
                        await context.read<NutritionRepository>().remove(e.id!);
                        reload();
                      },
                    ),
                  if (d.runKcal == 0 && isToday)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Astuce : après une course, un smoothie banane-lait ou une tartine '
                          'beurre de cacahuète dans les 30 min aide à récupérer (voir Idées recettes > Récupération).',
                          style: TextStyle(fontSize: 12)),
                    ),
                ]),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  final UserProfile profile;
  final _DayData data;
  const _Summary({required this.profile, required this.data});

  @override
  Widget build(BuildContext context) {
    final target = NutritionCalc.dailyTarget(profile, data.settings.activity, data.settings.goal, runKcal: data.runKcal);
    final macros = NutritionCalc.macros(profile, target, data.settings.goal);
    double sum(double Function(FoodEntry) f) => data.entries.fold(0, (s, e) => s + f(e));
    final eaten = sum((e) => e.kcal);
    final extras = data.entries.where((e) => e.extra).fold<double>(0, (s, e) => s + e.kcal);
    final left = target - eaten;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget bar(String label, double v, double max, Color c) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: t.labelSmall),
              LinearProgressIndicator(value: max == 0 ? 0 : (v / max).clamp(0, 1), color: c, minHeight: 6),
              Text('${v.round()} / ${max.round()} g', style: t.labelSmall),
            ]),
          ),
        );
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(left >= 0 ? 'Il te reste ${left.round()} kcal' : 'Dépassement de ${(-left).round()} kcal',
              style: t.headlineSmall?.copyWith(color: left >= 0 ? null : scheme.error)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (eaten / target).clamp(0, 1), minHeight: 10, borderRadius: BorderRadius.circular(5)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _kv('Objectif', '${target.round()}'),
            _kv('Mangé', '${eaten.round()}'),
            _kv('Courses', '+${data.runKcal.round()}'),
            _kv('Extras', '${extras.round()}'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            bar('Glucides', sum((e) => e.carbs), macros.carbsG, Colors.orange),
            bar('Protéines', sum((e) => e.protein), macros.proteinG, Colors.red),
            bar('Lipides', sum((e) => e.fat), macros.fatG, Colors.amber),
          ]),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Column(children: [
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(k, style: const TextStyle(fontSize: 12)),
      ]);
}

class _RaceAdvice extends StatelessWidget {
  final UserProfile profile;
  final _DayData data;
  final DateTime day;
  const _RaceAdvice({required this.profile, required this.data, required this.day});

  @override
  Widget build(BuildContext context) {
    final race = data.nextRace;
    if (race == null) return const SizedBox.shrink();
    final daysBefore = FoodEntry.dayOf(race.date).difference(day).inDays;
    final advice = RaceNutrition.advice(daysBefore: daysBefore, raceKm: race.distanceKm, weightKg: profile.weightKg);
    if (advice == null) return const SizedBox.shrink();
    final tag = daysBefore == 0 ? RecipeTag.preRace : RecipeTag.carbLoad;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🏅 ${race.name} ${daysBefore == 0 ? "aujourd'hui" : 'dans $daysBefore j'}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(advice),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipesScreen(initialTag: tag))),
            child: Text('Voir les recettes « ${tag.label} »'),
          ),
        ]),
      ),
    );
  }
}

class _Water extends StatelessWidget {
  final int ml;
  final int target;
  final ValueChanged<int> onChange;
  const _Water({required this.ml, required this.target, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: ListTile(
        leading: const Text('💧', style: TextStyle(fontSize: 24)),
        title: Text('Eau : ${(ml / 1000).toStringAsFixed(2).replaceAll('.', ',')} / ${(target / 1000).toStringAsFixed(1).replaceAll('.', ',')} L'),
        subtitle: LinearProgressIndicator(value: (ml / target).clamp(0, 1), color: Colors.lightBlue),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.remove), onPressed: ml == 0 ? null : () => onChange(ml - 250)),
          IconButton.filledTonal(icon: const Icon(Icons.add), tooltip: '+250 ml', onPressed: () => onChange(ml + 250)),
        ]),
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  final MealType meal;
  final List<FoodEntry> entries;
  final Recipe? planned;
  final VoidCallback onAdd;
  final ValueChanged<Recipe> onAddPlanned;
  final ValueChanged<FoodEntry> onDelete;

  const _MealSection({
    required this.meal,
    required this.entries,
    required this.planned,
    required this.onAdd,
    required this.onAddPlanned,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(0, (s, e) => s + e.kcal);
    final p = planned;
    final plannedEaten = p != null && entries.any((e) => e.recipeId == p.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
        title: Text(meal.label, style: Theme.of(context).textTheme.titleMedium),
        subtitle: total > 0 ? Text('${total.round()} kcal') : null,
        trailing: IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: onAdd),
      ),
      for (final e in entries)
        Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => onDelete(e),
          child: ListTile(
            dense: true,
            title: Text(e.name),
            subtitle: e.extra ? const Text('Extra') : null,
            trailing: Text('${e.kcal.round()} kcal'),
          ),
        ),
      if (p != null && !plannedEaten)
        ListTile(
          dense: true,
          leading: const Icon(Icons.event_note, size: 20),
          title: Text('Prévu : ${p.name}'),
          subtitle: Text('${p.kcal.round()} kcal'),
          trailing: TextButton(onPressed: () => onAddPlanned(p), child: const Text('Mangé ✓')),
        ),
    ]);
  }
}
