import 'dart:convert';

import 'package:course_appli/models/run.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sauvegarde : une course survit à l\'aller-retour JSON', () {
    final t0 = DateTime(2026, 11, 10, 8, 30);
    final run = Run(
      id: 12,
      startedAt: t0,
      movingTime: const Duration(minutes: 30),
      distanceM: 5123.4,
      elevationGainM: 42,
      elevationLossM: 40,
      calories: 380.5,
      steps: 5000,
      maxSpeedMps: 4.2,
      points: [
        for (var i = 0; i < 3; i++)
          TrackPoint(time: t0.add(Duration(seconds: i)), lat: 48.85 + i / 1e4, lng: 2.35, altitude: 35.5, accuracy: 4, speed: 3),
      ],
      checkpoints: [
        Checkpoint(time: t0, lat: 48.85, lng: 2.35, distanceM: 1000, elapsed: const Duration(minutes: 6), label: 'Pont'),
      ],
    );
    // Passage par une chaîne JSON, comme avec Supabase (les entiers deviennent parfois des doubles).
    final json = jsonDecode(jsonEncode(run.toBackupJson())) as Map<String, dynamic>;
    final back = Run.fromBackupJson(json);
    expect(back.id, isNull);
    expect(back.startedAt, t0);
    expect(back.distanceM, 5123.4);
    expect(back.movingTime, run.movingTime);
    expect(back.steps, 5000);
    expect(back.points.length, 3);
    expect(back.points[2].lat, closeTo(48.8502, 1e-9));
    expect(back.points[1].time, t0.add(const Duration(seconds: 1)));
    expect(back.checkpoints.single.label, 'Pont');
    expect(back.checkpoints.single.elapsed, const Duration(minutes: 6));
  });
}
