import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/run.dart';
import '../models/user_profile.dart';
import '../services/run_metrics.dart';
import '../services/run_repository.dart';
import '../services/voice_coach.dart';

enum TrackerState { idle, running, paused }

/// Pilote une course en cours : GPS, podomètre, chrono, checkpoints, annonces.
class RunTracker extends ChangeNotifier {
  final RunRepository repository;
  final VoiceCoach coach;

  RunTracker({required this.repository, required this.coach});

  TrackerState state = TrackerState.idle;
  RunMetrics? metrics;
  final List<Checkpoint> checkpoints = [];
  DateTime? startedAt;
  String? error;

  int steps = 0;
  int? _lastRawSteps;

  final Stopwatch _clock = Stopwatch();
  StreamSubscription<Position>? _posSub;
  StreamSubscription<StepCount>? _stepSub;
  Timer? _ticker;

  Duration get elapsed => _clock.elapsed;

  Future<bool> _ensurePermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      error = 'Active la localisation du téléphone.';
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      error = "L'accès à la position est nécessaire pour suivre la course.";
      return false;
    }
    await Permission.activityRecognition.request();
    await Permission.notification.request();
    return true;
  }

  Future<void> start(UserProfile profile) async {
    error = null;
    if (!await _ensurePermissions()) {
      notifyListeners();
      return;
    }
    metrics = RunMetrics(weightKg: profile.weightKg);
    checkpoints.clear();
    steps = 0;
    _lastRawSteps = null;
    startedAt = DateTime.now();
    coach.reset();
    _clock
      ..reset()
      ..start();
    state = TrackerState.running;

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 3,
      intervalDuration: const Duration(seconds: 1),
      // Service au premier plan : le suivi continue écran éteint.
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Course en cours',
        notificationText: 'Suivi GPS actif',
        enableWakeLock: true,
      ),
    );
    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);

    _stepSub = Pedometer.stepCountStream.listen((e) {
      // Le capteur renvoie le total depuis le démarrage du téléphone :
      // on ne cumule que les pas faits pendant que la course n'est pas en pause.
      final last = _lastRawSteps;
      _lastRawSteps = e.steps;
      if (last != null && state == TrackerState.running && e.steps >= last) {
        steps += e.steps - last;
        notifyListeners();
      }
    }, onError: (_) {});

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    await coach.say('Course démarrée. Bonne course !');
    notifyListeners();
  }

  void _onPosition(Position pos) {
    final m = metrics;
    if (m == null || state != TrackerState.running) return;
    m.add(TrackPoint(
      time: pos.timestamp,
      lat: pos.latitude,
      lng: pos.longitude,
      altitude: pos.altitude,
      accuracy: pos.accuracy,
      speed: pos.speed,
    ));
    coach.onProgress(distanceM: m.distanceM, elapsed: elapsed, avgSpeedMps: m.avgSpeedMps);
    notifyListeners();
  }

  void pause() {
    if (state != TrackerState.running) return;
    state = TrackerState.paused;
    _clock.stop();
    metrics?.breakSegment();
    coach.say('Pause.');
    notifyListeners();
  }

  void resume() {
    if (state != TrackerState.paused) return;
    state = TrackerState.running;
    _clock.start();
    coach.say('Reprise.');
    notifyListeners();
  }

  void addCheckpoint([String label = '']) {
    final m = metrics;
    if (m == null || m.points.isEmpty) return;
    final last = m.points.last;
    checkpoints.add(Checkpoint(
      time: DateTime.now(),
      lat: last.lat,
      lng: last.lng,
      distanceM: m.distanceM,
      elapsed: elapsed,
      label: label.isEmpty ? 'Checkpoint ${checkpoints.length + 1}' : label,
    ));
    coach.say('Checkpoint ${checkpoints.length} enregistré.');
    notifyListeners();
  }

  /// Termine la course et l'enregistre. Renvoie l'id, ou null si trop courte.
  Future<int?> stop() async {
    final m = metrics;
    await _cancel();
    state = TrackerState.idle;
    notifyListeners();
    if (m == null || m.points.length < 2) return null;
    final run = Run(
      startedAt: startedAt!,
      movingTime: m.movingTime,
      distanceM: m.distanceM,
      elevationGainM: m.elevationGainM,
      elevationLossM: m.elevationLossM,
      calories: m.calories,
      steps: steps,
      maxSpeedMps: m.maxSpeedMps,
      points: List.of(m.points),
      checkpoints: List.of(checkpoints),
    );
    await coach.say('Course terminée. ${(m.distanceM / 1000).toStringAsFixed(2).replaceAll('.', ',')} kilomètres. Bravo !');
    return repository.save(run);
  }

  Future<void> _cancel() async {
    _clock.stop();
    _ticker?.cancel();
    await _posSub?.cancel();
    await _stepSub?.cancel();
    _posSub = null;
    _stepSub = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }
}
