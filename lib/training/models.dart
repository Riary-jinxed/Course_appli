/// Objectif : une épreuve à préparer.
class RaceGoal {
  final int? id;
  final String name;
  final double distanceKm;
  final DateTime date;

  /// Temps visé (optionnel). Sert à calculer les allures d'entraînement.
  final Duration? targetTime;
  final int sessionsPerWeek;
  final DateTime createdAt;

  const RaceGoal({
    this.id,
    required this.name,
    required this.distanceKm,
    required this.date,
    this.targetTime,
    this.sessionsPerWeek = 3,
    required this.createdAt,
  });

  /// Allure de course visée en secondes par km.
  double? get racePaceSecPerKm =>
      targetTime == null ? null : targetTime!.inSeconds / distanceKm;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'distance_km': distanceKm,
        'date': date.millisecondsSinceEpoch,
        'target_s': targetTime?.inSeconds,
        'sessions_per_week': sessionsPerWeek,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory RaceGoal.fromMap(Map<String, dynamic> m) => RaceGoal(
        id: m['id'] as int?,
        name: m['name'] as String,
        distanceKm: (m['distance_km'] as num).toDouble(),
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        targetTime: m['target_s'] == null ? null : Duration(seconds: m['target_s'] as int),
        sessionsPerWeek: m['sessions_per_week'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}

enum SessionType {
  easy('Footing'),
  long('Sortie longue'),
  tempo('Allure seuil'),
  intervals('Fractionné'),
  race('Jour J');

  final String label;
  const SessionType(this.label);
}

/// Une séance prévue dans le programme.
class PlannedSession {
  final int? id;
  final int? goalId;
  final DateTime date;
  final SessionType type;
  final double distanceKm;

  /// Allure cible en s/km, si un temps visé a été donné.
  final int? targetPaceSec;
  final String description;

  /// Course réalisée qui valide cette séance (null si validée à la main).
  final int? runId;
  final bool done;

  const PlannedSession({
    this.id,
    this.goalId,
    required this.date,
    required this.type,
    required this.distanceKm,
    this.targetPaceSec,
    required this.description,
    this.runId,
    this.done = false,
  });

  Map<String, dynamic> toMap(int goalId) => {
        if (id != null) 'id': id,
        'goal_id': goalId,
        'date': date.millisecondsSinceEpoch,
        'type': type.name,
        'distance_km': distanceKm,
        'target_pace_s': targetPaceSec,
        'description': description,
        'run_id': runId,
        'done': done ? 1 : 0,
      };

  factory PlannedSession.fromMap(Map<String, dynamic> m) => PlannedSession(
        id: m['id'] as int?,
        goalId: m['goal_id'] as int?,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        type: SessionType.values.byName(m['type'] as String),
        distanceKm: (m['distance_km'] as num).toDouble(),
        targetPaceSec: m['target_pace_s'] as int?,
        description: m['description'] as String,
        runId: m['run_id'] as int?,
        done: (m['done'] as int? ?? 0) == 1,
      );
}
