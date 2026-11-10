import 'package:course_appli/models/run.dart';
import 'package:course_appli/records/best_efforts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Un point par seconde vers le nord ; 1 m ≈ 1/111195 degré de latitude.
  List<TrackPoint> track(List<double> speeds) {
    final t0 = DateTime(2026, 11, 10, 8);
    final pts = <TrackPoint>[];
    var lat = 0.0;
    for (var i = 0; i <= speeds.length; i++) {
      pts.add(TrackPoint(time: t0.add(Duration(seconds: i)), lat: lat, lng: 0, accuracy: 5));
      if (i < speeds.length) lat += speeds[i] / 111195;
    }
    return pts;
  }

  test('vitesse constante : 1 km à 4 m/s = 250 s', () {
    final b = bestEfforts(track(List.filled(600, 4)));
    expect(b[1000], closeTo(250, 1));
    expect(b.containsKey(5000), isFalse);
  });

  test('trouve la portion la plus rapide au milieu de la course', () {
    // 500 s à 2,5 m/s, 300 s à 5 m/s (1,5 km rapide), 500 s à 2,5 m/s.
    final b = bestEfforts(track([...List.filled(500, 2.5), ...List.filled(300, 5.0), ...List.filled(500, 2.5)]));
    expect(b[1000], closeTo(200, 1));
  });

  test('les sauts GPS sont ignorés', () {
    final pts = track(List.filled(400, 3));
    // Un point aberrant à 1 km de là.
    pts.insert(200, TrackPoint(time: pts[199].time.add(const Duration(milliseconds: 500)), lat: 0.01, lng: 0, accuracy: 5));
    final b = bestEfforts(pts);
    expect(b[1000], closeTo(1000 / 3, 2));
  });

  test('nouveaux records', () {
    expect(newRecords({1000: 240, 5000: 1300}, {1000: 250, 5000: 1250}), ['1 km']);
    expect(newRecords({10000: 3000}, {}), ['10 km']);
  });
}
