import '../models/user_profile.dart';

enum ActivityLevel {
  sedentary('Assis la plupart du temps', 1.2),
  standing('Souvent debout / en mouvement', 1.35),
  physical('Travail physique', 1.5);

  final String label;
  final double factor;
  const ActivityLevel(this.label, this.factor);
}

enum WeightGoal {
  lose('Perdre du poids'),
  maintain('Maintenir'),
  gain('Prendre du muscle');

  final String label;
  const WeightGoal(this.label);
}

class MacroTargets {
  final double kcal;
  final double carbsG;
  final double proteinG;
  final double fatG;
  const MacroTargets(this.kcal, this.carbsG, this.proteinG, this.fatG);
}

/// Calculs nutritionnels. Le sport n'est pas inclus dans le niveau d'activité :
/// les calories des courses enregistrées sont ajoutées jour par jour.
class NutritionCalc {
  /// Métabolisme de base (Mifflin-St Jeor), en kcal/jour.
  static double bmr(UserProfile p) {
    final age = p.age ?? 30;
    final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * age;
    return base +
        switch (p.sex) {
          Sex.male => 5,
          Sex.female => -161,
          Sex.other => -78,
        };
  }

  /// Dépense quotidienne hors sport.
  static double baseline(UserProfile p, ActivityLevel a) => bmr(p) * a.factor;

  /// Objectif calorique du jour, en tenant compte des courses du jour.
  /// En perte de poids : déficit de 15 % (500 kcal max) et seulement 70 % des
  /// calories de course « regagnées », pour ne pas trop creuser le déficit.
  static double dailyTarget(UserProfile p, ActivityLevel a, WeightGoal g, {double runKcal = 0}) {
    final base = baseline(p, a);
    return switch (g) {
      WeightGoal.lose => base - (base * 0.15).clamp(0, 500) + runKcal * 0.7,
      WeightGoal.maintain => base + runKcal,
      WeightGoal.gain => base * 1.1 + runKcal,
    };
  }

  /// Répartition : protéines 1,6 g/kg (2 g/kg en prise de muscle), lipides 27 %,
  /// le reste en glucides (carburant principal du coureur).
  static MacroTargets macros(UserProfile p, double kcal, WeightGoal g) {
    final protein = p.weightKg * (g == WeightGoal.gain ? 2.0 : 1.6);
    final fat = kcal * 0.27 / 9;
    final carbs = ((kcal - protein * 4 - fat * 9) / 4).clamp(0, double.infinity).toDouble();
    return MacroTargets(kcal, carbs, protein, fat);
  }

  /// Eau conseillée : 35 ml/kg + 600 ml par heure de course.
  static int waterMl(UserProfile p, {Duration running = Duration.zero}) =>
      (p.weightKg * 35 + running.inMinutes / 60 * 600).round();
}

/// Conseils d'alimentation autour d'une épreuve.
class RaceNutrition {
  /// Conseil pour un jour donné, selon le nombre de jours avant l'épreuve.
  /// Renvoie null s'il n'y a rien de particulier à faire.
  static String? advice({required int daysBefore, required double raceKm, required double weightKg}) {
    final w = weightKg;
    String g(double perKg) => '${(perKg * w).round()} g';
    if (daysBefore < 0) return null;
    if (daysBefore == 0) {
      return 'Jour J : petit-déjeuner riche en glucides et pauvre en fibres 3 h avant le départ '
          '(environ ${g(2)} de glucides), puis ${(w * 6).round()} ml d\'eau répartis jusqu\'au départ. '
          '${raceKm >= 15 ? 'Pendant la course : 30 à 60 g de glucides par heure (gels, boisson, pâtes de fruits).' : 'Rien de nouveau ce matin : que des aliments déjà testés.'}';
    }
    if (raceKm >= 21 && daysBefore <= 2) {
      return 'Recharge en glucides (J-$daysBefore) : vise environ ${g(8)} de glucides aujourd\'hui '
          '(pâtes, riz, pain, pommes de terre, fruits). Moins de fibres et de graisses, pas d\'alcool, bois régulièrement.';
    }
    if (raceKm >= 10 && daysBefore == 1) {
      return 'Veille d\'épreuve : repas riches en glucides (environ ${g(6)} sur la journée), dîner léger et tôt, '
          'pas de plat nouveau ni trop épicé, hydrate-toi bien.';
    }
    if (daysBefore <= 3) {
      return 'Épreuve dans $daysBefore jours : garde une alimentation simple et digeste, augmente un peu les féculents, '
          'évite l\'alcool et bois régulièrement.';
    }
    return null;
  }
}
