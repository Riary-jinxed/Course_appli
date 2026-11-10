/// Estimation des calories dépensées, basée sur les équations métaboliques de
/// l'ACSM (marche et course), qui tiennent compte de la vitesse et de la pente.
///
/// VO2 (ml/kg/min) = 3,5 + composante horizontale + composante verticale
/// kcal/min ≈ VO2 × poids(kg) / 1000 × 5
class CalorieCalculator {
  /// Vitesse (m/min) à partir de laquelle on considère qu'on court (~8 km/h).
  static const runningThresholdMpm = 134.0;

  /// Calories pour un segment parcouru à [speedMps] pendant [seconds],
  /// avec une pente [grade] (0,05 = 5 %). Les descentes ne sont pas comptées
  /// comme "négatives" : l'ACSM ne s'applique qu'aux pentes positives.
  static double segmentKcal({
    required double weightKg,
    required double speedMps,
    required double seconds,
    double grade = 0,
  }) {
    if (seconds <= 0 || weightKg <= 0) return 0;
    final s = speedMps * 60; // m/min
    final g = grade.clamp(0.0, 0.3);
    final double vo2;
    if (s < 1) {
      vo2 = 3.5; // au repos
    } else if (s < runningThresholdMpm) {
      vo2 = 3.5 + 0.1 * s + 1.8 * s * g;
    } else {
      vo2 = 3.5 + 0.2 * s + 0.9 * s * g;
    }
    final kcalPerMin = vo2 * weightKg / 1000 * 5;
    return kcalPerMin * seconds / 60;
  }
}
