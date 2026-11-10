import 'dart:math';
import 'dart:ui';

import '../models/run.dart';
import '../services/geo.dart';

/// Rampe de couleurs de l'allure : du plus lent (froid) au plus rapide (chaud).
const paceRamp = [
  Color(0xFF3D7BFF), // lent
  Color(0xFF16C79A),
  Color(0xFFFFD23F),
  Color(0xFFFF8A1F),
  Color(0xFFE5383B), // rapide
];

/// Couleur sur la rampe pour une valeur normalisée entre 0 (lent) et 1 (rapide).
Color paceColor(double t) {
  final x = t.clamp(0.0, 1.0) * (paceRamp.length - 1);
  final i = x.floor().clamp(0, paceRamp.length - 2);
  return Color.lerp(paceRamp[i], paceRamp[i + 1], x - i)!;
}

/// Un morceau du tracé d'une seule couleur.
class PaceSegment {
  /// Indices (inclus) des points du tracé couverts par ce morceau.
  final int from;
  final int to;
  final Color color;
  const PaceSegment(this.from, this.to, this.color);
}

/// Découpe le tracé en morceaux colorés selon l'allure.
///
/// La vitesse de chaque tronçon est lissée sur environ [windowM] mètres pour
/// gommer le bruit du GPS, puis normalisée entre les 10e et 90e centiles de la
/// course : les couleurs restent lisibles qu'on coure à 4 ou à 7 min/km.
/// Les vitesses sont regroupées en [levels] niveaux pour limiter le nombre
/// de morceaux à dessiner.
List<PaceSegment> paceSegments(List<TrackPoint> points, {double windowM = 120, int levels = 12}) {
  if (points.length < 2) return const [];
  final n = points.length - 1; // nombre de tronçons
  final dist = List<double>.filled(n, 0);
  final secs = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final a = points[i], b = points[i + 1];
    dist[i] = haversineM(a.lat, a.lng, b.lat, b.lng);
    secs[i] = max(0, b.time.difference(a.time).inMilliseconds / 1000);
  }

  // Lissage : fenêtre glissante centrée, bornée en distance.
  final speed = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    var d = dist[i], s = secs[i];
    var lo = i, hi = i;
    while (d < windowM && (lo > 0 || hi < n - 1)) {
      if (lo > 0) {
        lo--;
        d += dist[lo];
        s += secs[lo];
      }
      if (hi < n - 1) {
        hi++;
        d += dist[hi];
        s += secs[hi];
      }
    }
    speed[i] = s > 0 ? d / s : 0;
  }

  final sorted = [...speed]..sort();
  double pct(double p) => sorted[((sorted.length - 1) * p).round()];
  final slow = pct(0.1), fast = pct(0.9);
  final range = fast - slow;

  int level(double v) {
    if (range < 0.05) return levels ~/ 2; // allure quasi constante
    final t = ((v - slow) / range).clamp(0.0, 1.0);
    return (t * (levels - 1)).round();
  }

  final out = <PaceSegment>[];
  var start = 0;
  var current = level(speed[0]);
  for (var i = 1; i <= n; i++) {
    final l = i < n ? level(speed[i]) : -1;
    if (l != current) {
      out.add(PaceSegment(start, i, paceColor(current / (levels - 1))));
      start = i;
      current = l;
    }
  }
  return out;
}

/// Position (index du point) de chaque kilomètre complet parcouru.
List<int> kilometerMarks(List<TrackPoint> points) {
  final marks = <int>[];
  var d = 0.0;
  var next = 1000.0;
  for (var i = 1; i < points.length; i++) {
    d += haversineM(points[i - 1].lat, points[i - 1].lng, points[i].lat, points[i].lng);
    if (d >= next) {
      marks.add(i);
      next += 1000;
    }
  }
  return marks;
}
