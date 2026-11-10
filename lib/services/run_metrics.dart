import '../models/run.dart';
import 'calories.dart';
import 'geo.dart';

/// Calcule en continu les stats de la course à partir des points GPS.
/// Classe pure (sans plugin) pour pouvoir la tester facilement.
class RunMetrics {
  final double weightKg;

  /// Les points moins précis que ça (en mètres) sont ignorés.
  final double maxAccuracyM;

  /// En dessous de cette vitesse on considère qu'on est à l'arrêt (auto-pause).
  final double minMovingSpeedMps;

  final ElevationAccumulator _elev = ElevationAccumulator();
  final List<TrackPoint> points = [];

  double distanceM = 0;
  double calories = 0;
  double maxSpeedMps = 0;
  Duration movingTime = Duration.zero;

  /// Vitesse lissée sur les derniers points, pour l'affichage en direct.
  double currentSpeedMps = 0;

  RunMetrics({
    required this.weightKg,
    this.maxAccuracyM = 25,
    this.minMovingSpeedMps = 0.5,
  });

  double get elevationGainM => _elev.gain;
  double get elevationLossM => _elev.loss;
  double get avgSpeedMps =>
      movingTime.inMilliseconds == 0 ? 0 : distanceM / (movingTime.inMilliseconds / 1000);

  bool _segmentBroken = false;

  /// Après une pause : le prochain point ne sera pas relié au précédent.
  void breakSegment() => _segmentBroken = true;

  /// Ajoute un point. Renvoie false s'il a été rejeté (précision trop faible).
  bool add(TrackPoint p) {
    if (p.accuracy > maxAccuracyM) return false;
    final prev = points.isEmpty || _segmentBroken ? null : points.last;
    _segmentBroken = false;
    points.add(p);
    _elev.add(p.altitude);
    if (prev == null) return true;

    final dt = p.time.difference(prev.time).inMilliseconds / 1000;
    if (dt <= 0) return true;
    final d = haversineM(prev.lat, prev.lng, p.lat, p.lng);
    final speed = d / dt;

    // Saut GPS aberrant (> 12 m/s ≈ 43 km/h) : on ignore le segment.
    if (speed > 12) return true;

    currentSpeedMps = currentSpeedMps == 0 ? speed : currentSpeedMps * 0.7 + speed * 0.3;

    if (speed >= minMovingSpeedMps) {
      distanceM += d;
      movingTime += Duration(milliseconds: (dt * 1000).round());
      if (speed > maxSpeedMps) maxSpeedMps = speed;
      final grade = d > 0 ? (p.altitude - prev.altitude) / d : 0.0;
      calories += CalorieCalculator.segmentKcal(
        weightKg: weightKg,
        speedMps: speed,
        seconds: dt,
        grade: grade,
      );
    }
    return true;
  }
}
