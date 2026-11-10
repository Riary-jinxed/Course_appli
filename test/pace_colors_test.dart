import 'package:course_appli/map/pace_colors.dart';
import 'package:course_appli/models/run.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tracé rectiligne vers le nord : [speeds] en m/s, un point toutes les 10 s.
List<TrackPoint> track(List<double> speeds) {
  final t0 = DateTime(2026, 1, 1, 8);
  var lat = 48.0;
  final pts = [TrackPoint(time: t0, lat: lat, lng: 2)];
  for (final (i, v) in speeds.indexed) {
    lat += v * 10 / 111195; // mètres -> degrés de latitude
    pts.add(TrackPoint(time: t0.add(Duration(seconds: 10 * (i + 1))), lat: lat, lng: 2));
  }
  return pts;
}

void main() {
  test('les morceaux couvrent tout le tracé sans trou', () {
    final pts = track([...List.filled(30, 2.5), ...List.filled(30, 4.0), ...List.filled(30, 3.0)]);
    final segs = paceSegments(pts);
    expect(segs.first.from, 0);
    expect(segs.last.to, pts.length - 1);
    for (var i = 1; i < segs.length; i++) {
      expect(segs[i].from, segs[i - 1].to);
    }
  });

  test('la partie rapide est plus chaude que la partie lente', () {
    final pts = track([...List.filled(40, 2.5), ...List.filled(40, 4.5)]);
    final segs = paceSegments(pts);
    expect(segs.first.color, paceColor(0));
    expect(segs.last.color, paceColor(1));
  });

  test('allure constante : une seule couleur', () {
    final segs = paceSegments(track(List.filled(50, 3.0)));
    expect(segs.length, 1);
  });

  test('bornes kilométriques', () {
    // 3,2 km à 4 m/s, un point tous les 40 m.
    final marks = kilometerMarks(track(List.filled(80, 4.0)));
    expect(marks.length, 3);
    expect(marks.first, inInclusiveRange(25, 26));
  });
}
