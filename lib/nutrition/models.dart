enum MealType {
  breakfast('Petit-déjeuner', 0.25),
  lunch('Déjeuner', 0.35),
  dinner('Dîner', 0.30),
  snack('Collations', 0.10);

  final String label;

  /// Part de l'objectif calorique du jour.
  final double share;
  const MealType(this.label, this.share);
}

enum RecipeTag {
  breakfast('Petit-déj'),
  main('Plat'),
  snack('Collation'),
  preRace('Avant course'),
  carbLoad('Recharge glucides'),
  recovery('Récupération'),
  light('Léger');

  final String label;
  const RecipeTag(this.label);
}

class Recipe {
  final String id;
  final String name;
  final int minutes;
  final double kcal;
  final double carbs;
  final double protein;
  final double fat;
  final Set<RecipeTag> tags;
  final List<String> ingredients;
  final List<String> steps;

  const Recipe({
    required this.id,
    required this.name,
    required this.minutes,
    required this.kcal,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.tags,
    required this.ingredients,
    required this.steps,
  });
}

/// Aliment rapide (grignotage / extra) avec valeurs approximatives.
class QuickFood {
  final String emoji;
  final String name;
  final double kcal;
  final double carbs;
  final double protein;
  final double fat;
  const QuickFood(this.emoji, this.name, this.kcal, this.carbs, this.protein, this.fat);
}

/// Un aliment ou repas noté dans le journal.
class FoodEntry {
  final int? id;
  final DateTime day;
  final MealType meal;
  final String name;
  final double kcal;
  final double carbs;
  final double protein;
  final double fat;

  /// Grignotage ou écart (affiché à part dans le bilan).
  final bool extra;
  final String? recipeId;

  const FoodEntry({
    this.id,
    required this.day,
    required this.meal,
    required this.name,
    required this.kcal,
    this.carbs = 0,
    this.protein = 0,
    this.fat = 0,
    this.extra = false,
    this.recipeId,
  });

  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'day': dayOf(day).millisecondsSinceEpoch,
        'meal': meal.name,
        'name': name,
        'kcal': kcal,
        'carbs': carbs,
        'protein': protein,
        'fat': fat,
        'extra': extra ? 1 : 0,
        'recipe_id': recipeId,
      };

  factory FoodEntry.fromMap(Map<String, dynamic> m) => FoodEntry(
        id: m['id'] as int?,
        day: DateTime.fromMillisecondsSinceEpoch(m['day'] as int),
        meal: MealType.values.byName(m['meal'] as String),
        name: m['name'] as String,
        kcal: (m['kcal'] as num).toDouble(),
        carbs: (m['carbs'] as num).toDouble(),
        protein: (m['protein'] as num).toDouble(),
        fat: (m['fat'] as num).toDouble(),
        extra: (m['extra'] as int) == 1,
        recipeId: m['recipe_id'] as String?,
      );

  factory FoodEntry.fromRecipe(Recipe r, DateTime day, MealType meal, {double portions = 1}) => FoodEntry(
        day: day,
        meal: meal,
        name: portions == 1 ? r.name : '${r.name} ×${portions.toStringAsFixed(1).replaceAll('.0', '')}',
        kcal: r.kcal * portions,
        carbs: r.carbs * portions,
        protein: r.protein * portions,
        fat: r.fat * portions,
        recipeId: r.id,
      );

  factory FoodEntry.fromQuick(QuickFood q, DateTime day, MealType meal, {bool extra = true}) => FoodEntry(
        day: day,
        meal: meal,
        name: '${q.emoji} ${q.name}',
        kcal: q.kcal,
        carbs: q.carbs,
        protein: q.protein,
        fat: q.fat,
        extra: extra,
      );
}
