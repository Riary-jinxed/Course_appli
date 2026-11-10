/// Un point GPS enregistré pendant une course.
class TrackPoint {
  final DateTime time;
  final double lat;
  final double lng;
  final double altitude;
  final double accuracy;
  final double speed; // m/s, tel que fourni par le GPS

  const TrackPoint({
    required this.time,
    required this.lat,
    required this.lng,
    this.altitude = 0,
    this.accuracy = 0,
    this.speed = 0,
  });

  Map<String, dynamic> toMap(int runId) => {
        'run_id': runId,
        'time': time.millisecondsSinceEpoch,
        'lat': lat,
        'lng': lng,
        'altitude': altitude,
        'accuracy': accuracy,
        'speed': speed,
      };

  factory TrackPoint.fromMap(Map<String, dynamic> m) => TrackPoint(
        time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        altitude: (m['altitude'] as num).toDouble(),
        accuracy: (m['accuracy'] as num).toDouble(),
        speed: (m['speed'] as num).toDouble(),
      );
}

/// Un checkpoint marqué pendant la course (manuellement, plus tard à la voix).
class Checkpoint {
  final DateTime time;
  final double lat;
  final double lng;
  final double distanceM;
  final Duration elapsed;
  final String label;

  const Checkpoint({
    required this.time,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.elapsed,
    this.label = '',
  });

  Map<String, dynamic> toMap(int runId) => {
        'run_id': runId,
        'time': time.millisecondsSinceEpoch,
        'lat': lat,
        'lng': lng,
        'distance_m': distanceM,
        'elapsed_ms': elapsed.inMilliseconds,
        'label': label,
      };

  factory Checkpoint.fromMap(Map<String, dynamic> m) => Checkpoint(
        time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        distanceM: (m['distance_m'] as num).toDouble(),
        elapsed: Duration(milliseconds: m['elapsed_ms'] as int),
        label: m['label'] as String? ?? '',
      );
}

/// Résumé d'une course terminée.
class Run {
  final int? id;
  final DateTime startedAt;
  final Duration movingTime;
  final double distanceM;
  final double elevationGainM;
  final double elevationLossM;
  final double calories;
  final int steps;
  final double maxSpeedMps;
  final List<TrackPoint> points;
  final List<Checkpoint> checkpoints;

  const Run({
    this.id,
    required this.startedAt,
    required this.movingTime,
    required this.distanceM,
    required this.elevationGainM,
    required this.elevationLossM,
    required this.calories,
    required this.steps,
    required this.maxSpeedMps,
    this.points = const [],
    this.checkpoints = const [],
  });

  double get avgSpeedMps =>
      movingTime.inMilliseconds == 0 ? 0 : distanceM / (movingTime.inMilliseconds / 1000);

  /// Cadence moyenne en pas par minute.
  double get cadence =>
      movingTime.inSeconds == 0 ? 0 : steps / (movingTime.inSeconds / 60);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'started_at': startedAt.millisecondsSinceEpoch,
        'moving_ms': movingTime.inMilliseconds,
        'distance_m': distanceM,
        'elev_gain_m': elevationGainM,
        'elev_loss_m': elevationLossM,
        'calories': calories,
        'steps': steps,
        'max_speed_mps': maxSpeedMps,
      };

  factory Run.fromMap(Map<String, dynamic> m,
          {List<TrackPoint> points = const [], List<Checkpoint> checkpoints = const []}) =>
      Run(
        id: m['id'] as int?,
        startedAt: DateTime.fromMillisecondsSinceEpoch(m['started_at'] as int),
        movingTime: Duration(milliseconds: m['moving_ms'] as int),
        distanceM: (m['distance_m'] as num).toDouble(),
        elevationGainM: (m['elev_gain_m'] as num).toDouble(),
        elevationLossM: (m['elev_loss_m'] as num).toDouble(),
        calories: (m['calories'] as num).toDouble(),
        steps: m['steps'] as int,
        maxSpeedMps: (m['max_speed_mps'] as num).toDouble(),
        points: points,
        checkpoints: checkpoints,
      );

  /// Format compact pour la sauvegarde en ligne (points en tableaux).
  Map<String, dynamic> toBackupJson() => {
        'v': 1,
        ...toMap()..remove('id'),
        'points': [
          for (final p in points)
            [p.time.millisecondsSinceEpoch, p.lat, p.lng, p.altitude, p.accuracy, p.speed]
        ],
        'checkpoints': [for (final c in checkpoints) c.toMap(0)..remove('run_id')],
      };

  factory Run.fromBackupJson(Map<String, dynamic> j) {
    double d(dynamic v) => (v as num).toDouble();
    return Run.fromMap(
      Map<String, dynamic>.from(j)..remove('id'),
      points: [
        for (final p in (j['points'] as List).cast<List>())
          TrackPoint(
            time: DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()),
            lat: d(p[1]),
            lng: d(p[2]),
            altitude: d(p[3]),
            accuracy: d(p[4]),
            speed: d(p[5]),
          )
      ],
      checkpoints: [
        for (final c in (j['checkpoints'] as List).cast<Map>()) Checkpoint.fromMap(c.cast<String, dynamic>())
      ],
    );
  }
}
