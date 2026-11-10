import '../models/run.dart';
import '../services/geo.dart';

/// Distances suivies pour les records (en mètres) et leur libellé.
const recordDistances = <int, String>{
  1000: '1 km',
  5000: '5 km',
  10000: '10 km',
  21097: 'Semi-marathon',
  42195: 'Marathon',
};

/// Meilleur temps (en secondes) pour chaque distance couverte pendant la course.
///
/// On cherche, sur le tracé, la portion continue la plus rapide d'au moins
/// D mètres (fenêtre glissante), en interpolant au mètre près. Les points peu
/// précis ou les sauts GPS sont ignorés, comme pour le calcul de distance.
Map<int, double> bestEfforts(List<TrackPoint> points, {Iterable<int> distances = const [1000, 5000, 10000, 21097, 42195]}) {
  // Distance cumulée et temps de chaque point retenu.
  final dist = <double>[];
  final time = <double>[];
  TrackPoint? prev;
  for (final p in points) {
    if (p.accuracy > 25) continue;
    if (prev == null) {
      dist.add(0);
      time.add(p.time.millisecondsSinceEpoch / 1000);
      prev = p;
      continue;
    }
    final dt = p.time.difference(prev.time).inMilliseconds / 1000;
    if (dt <= 0) continue;
    final d = haversineM(prev.lat, prev.lng, p.lat, p.lng);
    if (d / dt > 12) continue; // saut GPS
    dist.add(dist.last + d);
    time.add(p.time.millisecondsSinceEpoch / 1000);
    prev = p;
  }

  final result = <int, double>{};
  if (dist.length < 2) return result;
  for (final target in distances) {
    if (dist.last < target) continue;
    double? best;
    var j = 0;
    for (var i = 0; i < dist.length; i++) {
      // Premier point j tel que dist[j] - dist[i] >= target.
      if (j < i) j = i;
      while (j < dist.length && dist[j] - dist[i] < target) {
        j++;
      }
      if (j >= dist.length) break;
      // Interpolation : temps exact où l'on atteint dist[i] + target.
      final over = dist[j] - dist[i] - target;
      final segD = dist[j] - dist[j - 1];
      final segT = time[j] - time[j - 1];
      final t = (time[j] - (segD == 0 ? 0 : over / segD * segT)) - time[i];
      if (best == null || t < best) best = t;
    }
    if (best != null) result[target] = best;
  }
  return result;
}

/// Un record personnel.
class PersonalRecord {
  final String label;
  final String value;
  final int? runId;
  final DateTime? date;
  const PersonalRecord(this.label, this.value, this.runId, this.date);
}

/// Records battus par [run] par rapport aux meilleurs temps précédents.
List<String> newRecords(Map<int, double> runBests, Map<int, double> previousBests) => [
      for (final e in runBests.entries)
        if (!previousBests.containsKey(e.key) || e.value < previousBests[e.key]! - 0.5)
          recordDistances[e.key] ?? '${e.key} m',
    ];
