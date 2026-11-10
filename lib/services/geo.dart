import 'dart:math';

const _earthRadiusM = 6371000.0;

/// Distance en mètres entre deux coordonnées (formule de haversine).
double haversineM(double lat1, double lng1, double lat2, double lng2) {
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return 2 * _earthRadiusM * atan2(sqrt(a), sqrt(1 - a));
}

/// Cumule le dénivelé positif et négatif en ignorant le bruit du GPS.
///
/// L'altitude GPS varie de quelques mètres même à l'arrêt : on ne compte une
/// montée ou une descente qu'une fois l'écart avec le dernier palier validé
/// supérieur à [threshold] mètres.
class ElevationAccumulator {
  final double threshold;
  double? _ref;
  double gain = 0;
  double loss = 0;

  ElevationAccumulator({this.threshold = 3});

  void add(double altitude) {
    final ref = _ref;
    if (ref == null) {
      _ref = altitude;
      return;
    }
    final diff = altitude - ref;
    if (diff >= threshold) {
      gain += diff;
      _ref = altitude;
    } else if (diff <= -threshold) {
      loss += -diff;
      _ref = altitude;
    }
  }
}

/// Formate une allure (secondes par km) en "m:ss".
String formatPace(double speedMps) {
  if (speedMps <= 0.3) return '--:--';
  final secPerKm = 1000 / speedMps;
  final m = secPerKm ~/ 60;
  final s = (secPerKm % 60).round();
  return s == 60 ? '${m + 1}:00' : '$m:${s.toString().padLeft(2, '0')}';
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
