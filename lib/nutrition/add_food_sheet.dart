import 'package:flutter/material.dart';

import 'models.dart';
import 'recipes.dart';

/// Choix d'un aliment : recette, grignotage rapide ou saisie libre.
/// Renvoie l'entrée à ajouter (ou null).
Future<FoodEntry?> showAddFoodSheet(BuildContext context, DateTime day, MealType meal, {int initialTab = 0}) {
  return showModalBottomSheet<FoodEntry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _AddFood(day: day, meal: meal, initialTab: initialTab),
    ),
  );
}

class _AddFood extends StatefulWidget {
  final DateTime day;
  final MealType meal;
  final int initialTab;
  const _AddFood({required this.day, required this.meal, required this.initialTab});

  @override
  State<_AddFood> createState() => _AddFoodState();
}

class _AddFoodState extends State<_AddFood> {
  late MealType _meal = widget.meal;
  String _query = '';
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _carbs = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  bool _extra = false;

  double _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final filtered = recipes.where((r) => r.name.toLowerCase().contains(_query.toLowerCase())).toList();
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: DropdownButtonFormField<MealType>(
            initialValue: _meal,
            decoration: const InputDecoration(labelText: 'Repas'),
            items: [for (final m in MealType.values) DropdownMenuItem(value: m, child: Text(m.label))],
            onChanged: (m) => setState(() => _meal = m!),
          ),
        ),
        const TabBar(tabs: [Tab(text: 'Recettes'), Tab(text: 'Grignotage / extra'), Tab(text: 'Libre')]),
        Expanded(
          child: TabBarView(children: [
            ListView(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Chercher une recette'),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              for (final r in filtered)
                ListTile(
                  title: Text(r.name),
                  subtitle: Text('${r.kcal.round()} kcal · G ${r.carbs.round()} g · P ${r.protein.round()} g'),
                  trailing: PopupMenuButton<double>(
                    tooltip: 'Portions',
                    icon: const Icon(Icons.add_circle_outline),
                    itemBuilder: (_) => [
                      for (final p in [0.5, 1.0, 1.5, 2.0])
                        PopupMenuItem(value: p, child: Text('${p.toString().replaceAll('.0', '')} portion${p > 1 ? 's' : ''}')),
                    ],
                    onSelected: (p) => Navigator.pop(context, FoodEntry.fromRecipe(r, widget.day, _meal, portions: p)),
                  ),
                  onTap: () => Navigator.pop(context, FoodEntry.fromRecipe(r, widget.day, _meal)),
                ),
            ]),
            GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(12),
              childAspectRatio: 1.1,
              children: [
                for (final q in quickFoods)
                  Card(
                    child: InkWell(
                      onTap: () => Navigator.pop(
                          context, FoodEntry.fromQuick(q, widget.day, _meal, extra: !q.name.contains('Gel'))),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(q.emoji, style: const TextStyle(fontSize: 28)),
                        Text(q.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                        Text('${q.kcal.round()} kcal', style: const TextStyle(fontSize: 11)),
                      ]),
                    ),
                  ),
              ],
            ),
            ListView(padding: const EdgeInsets.all(16), children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Aliment ou plat')),
              TextField(
                controller: _kcal,
                decoration: const InputDecoration(labelText: 'Calories', suffixText: 'kcal'),
                keyboardType: TextInputType.number,
              ),
              Row(children: [
                for (final (c, l) in [(_carbs, 'Glucides'), (_protein, 'Protéines'), (_fat, 'Lipides')])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextField(
                        controller: c,
                        decoration: InputDecoration(labelText: l, suffixText: 'g'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
              ]),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _extra,
                onChanged: (v) => setState(() => _extra = v!),
                title: const Text('C\'est un écart / grignotage'),
              ),
              FilledButton(
                onPressed: () {
                  if (_name.text.trim().isEmpty || _n(_kcal) <= 0) return;
                  Navigator.pop(
                    context,
                    FoodEntry(
                      day: widget.day,
                      meal: _meal,
                      name: _name.text.trim(),
                      kcal: _n(_kcal),
                      carbs: _n(_carbs),
                      protein: _n(_protein),
                      fat: _n(_fat),
                      extra: _extra,
                    ),
                  );
                },
                child: const Text('Ajouter'),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
