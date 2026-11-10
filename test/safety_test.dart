import 'package:course_appli/models/run.dart';
import 'package:course_appli/safety/safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('échantillonnage du tracé pour le suivi en direct', () {
    final t0 = DateTime(2026);
    final pts = [for (var i = 0; i < 1000; i++) TrackPoint(time: t0, lat: 48 + i / 1e4, lng: 2)];
    final s = downsampleTrail(pts, max: 300);
    expect(s.length, lessThanOrEqualTo(301));
    expect(s.first, [48.0, 2.0]);
    expect(s.last[0], closeTo(48.0999, 1e-6)); // le dernier point est toujours inclus
    expect(downsampleTrail([]), isEmpty);
  });

  test('lien carte', () {
    expect(mapsLink(48.856613, 2.352222), 'https://maps.google.com/?q=48.85661,2.35222');
  });
}
