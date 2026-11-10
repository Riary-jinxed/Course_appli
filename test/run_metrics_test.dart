import 'package:course_appli/models/run.dart';
import 'package:course_appli/services/calories.dart';
import 'package:course_appli/services/geo.dart';
import 'package:course_appli/services/run_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('haversine : 1 degré de latitude ≈ 111 km', () {
    expect(haversineM(0, 0, 1, 0), closeTo(111195, 50));
  });

  test('dénivelé : le bruit sous le seuil est ignoré', () {
    final e = ElevationAccumulator(threshold: 3);
    for (final a in <double>[100, 101, 99.5, 100.5, 104, 108, 106, 103, 103.5]) {
      e.add(a);
    }
    expect(e.gain, closeTo(8, 0.01)); // 100 -> 104 -> 108
    expect(e.loss, closeTo(5, 0.01)); // 108 -> 103
  });

  test('calories : 70 kg, 10 km/h pendant 1 h ≈ 770 kcal', () {
    final kcal = CalorieCalculator.segmentKcal(
      weightKg: 70,
      speedMps: 10000 / 3600,
      seconds: 3600,
    );
    expect(kcal, closeTo(773, 10));
  });

  test('allure', () {
    expect(formatPace(1000 / 300), '5:00');
    expect(formatPace(0), '--:--');
  });

  test('RunMetrics : distance, temps et rejet des points imprécis', () {
    final m = RunMetrics(weightKg: 70);
    final t0 = DateTime(2026, 1, 1, 8);
    // ~3 m/s vers le nord, un point toutes les secondes.
    for (var i = 0; i <= 100; i++) {
      m.add(TrackPoint(time: t0.add(Duration(seconds: i)), lat: i * 0.000027, lng: 0, accuracy: 5));
    }
    expect(m.add(TrackPoint(time: t0.add(const Duration(seconds: 101)), lat: 1, lng: 1, accuracy: 80)),
        isFalse);
    expect(m.distanceM, closeTo(300, 5));
    expect(m.movingTime.inSeconds, 100);
    expect(m.calories, greaterThan(0));
  });
}
