import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'nutrition_repository.dart';
import 'recipes.dart';

class RecipesScreen extends StatefulWidget {
  final RecipeTag? initialTag;
  const RecipesScreen({super.key, this.initialTag});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  late RecipeTag? _tag = widget.initialTag;
  bool _favOnly = false;
  Set<String> _fav = {};

  @override
  void initState() {
    super.initState();
    _loadFav();
  }

  Future<void> _loadFav() async {
    final f = await context.read<NutritionRepository>().favorites();
    if (mounted) setState(() => _fav = f);
  }

  @override
  Widget build(BuildContext context) {
    final list = recipes
        .where((r) => _tag == null || r.tags.contains(_tag))
        .where((r) => !_favOnly || _fav.contains(r.id))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Idées recettes')),
      body: ListView(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            FilterChip(
              avatar: const Icon(Icons.favorite, size: 16),
              label: const Text('Favoris'),
              selected: _favOnly,
              onSelected: (v) => setState(() => _favOnly = v),
            ),
            const SizedBox(width: 6),
            for (final t in RecipeTag.values) ...[
              ChoiceChip(
                label: Text(t.label),
                selected: _tag == t,
                onSelected: (v) => setState(() => _tag = v ? t : null),
              ),
              const SizedBox(width: 6),
            ],
          ]),
        ),
        for (final r in list)
          ListTile(
            title: Text(r.name),
            subtitle: Text('${r.kcal.round()} kcal · ${r.minutes} min · ${r.tags.map((t) => t.label).join(', ')}'),
            trailing: Icon(_fav.contains(r.id) ? Icons.favorite : Icons.chevron_right,
                color: _fav.contains(r.id) ? Colors.red : null),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: r)));
              _loadFav();
            },
          ),
      ]),
    );
  }
}

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _fav = false;

  @override
  void initState() {
    super.initState();
    context.read<NutritionRepository>().favorites().then((f) {
      if (mounted) setState(() => _fav = f.contains(widget.recipe.id));
    });
  }

  Future<void> _add() async {
    final repo = context.read<NutritionRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final meal = await showDialog<MealType>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Ajouter à aujourd\'hui'),
        children: [
          for (final m in MealType.values)
            SimpleDialogOption(onPressed: () => Navigator.pop(c, m), child: Text(m.label)),
        ],
      ),
    );
    if (meal == null) return;
    await repo.add(FoodEntry.fromRecipe(widget.recipe, DateTime.now(), meal));
    messenger.showSnackBar(SnackBar(content: Text('Ajouté au ${meal.label.toLowerCase()}')));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(r.name), actions: [
        IconButton(
          icon: Icon(_fav ? Icons.favorite : Icons.favorite_border, color: _fav ? Colors.red : null),
          onPressed: () async {
            await context.read<NutritionRepository>().toggleFavorite(r.id);
            setState(() => _fav = !_fav);
          },
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('J\'ai mangé ça'),
        onPressed: _add,
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: Text('${r.kcal.round()} kcal')),
          Chip(label: Text('Glucides ${r.carbs.round()} g')),
          Chip(label: Text('Protéines ${r.protein.round()} g')),
          Chip(label: Text('Lipides ${r.fat.round()} g')),
          Chip(avatar: const Icon(Icons.timer, size: 16), label: Text('${r.minutes} min')),
        ]),
        const SizedBox(height: 16),
        Text('Ingrédients (1 portion)', style: t.titleMedium),
        for (final i in r.ingredients) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $i')),
        const SizedBox(height: 16),
        Text('Préparation', style: t.titleMedium),
        for (final (n, s) in r.steps.indexed)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('${n + 1}. $s')),
      ]),
    );
  }
}
