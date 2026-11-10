import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../controllers/run_tracker.dart';
import '../main.dart';
import '../services/geo.dart';
import '../services/run_repository.dart';
import '../social/backup_service.dart';
import '../training/plan_repository.dart';
import '../widgets/route_map.dart';
import '../widgets/stat_tile.dart';
import 'run_detail_screen.dart';

class LiveRunScreen extends StatefulWidget {
  const LiveRunScreen({super.key});

  @override
  State<LiveRunScreen> createState() => _LiveRunScreenState();
}

class _LiveRunScreenState extends State<LiveRunScreen> {
  final _map = MapController();
  int _lastPointCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<ProfileState>().profile!;
      context.read<RunTracker>().start(profile);
    });
  }

  Future<void> _finish(RunTracker t) async {
    final plans = context.read<PlanRepository>();
    final runs = context.read<RunRepository>();
    final backup = context.read<BackupService>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Terminer la course ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continuer')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Terminer')),
        ],
      ),
    );
    if (ok != true) return;
    final id = await t.stop();
    if (id != null) {
      final run = await runs.get(id);
      if (run != null) backup.backup(run);
      final session = run == null ? null : await plans.matchRun(id, run);
      if (session != null) {
        messenger.showSnackBar(SnackBar(content: Text('Séance validée : ${session.type.label} ✓')));
      }
    }
    if (!mounted) return;
    if (id == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Course trop courte, non enregistrée.')));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => RunDetailScreen(runId: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<RunTracker>();
    final m = t.metrics;
    final points = m?.points ?? const [];

    // Recentre la carte sur le coureur à chaque nouveau point.
    if (points.length != _lastPointCount && points.isNotEmpty) {
      _lastPointCount = points.length;
      final last = points.last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _map.move(LatLng(last.lat, last.lng), _map.camera.zoom < 14 ? 16 : _map.camera.zoom);
        } catch (_) {}
      });
    }

    return PopScope(
      canPop: t.state == TrackerState.idle,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(t);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(t.state == TrackerState.paused ? 'En pause' : 'Course en cours')),
        body: Column(
          children: [
            if (t.error != null)
              MaterialBanner(content: Text(t.error!), actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ]),
            Expanded(
              flex: 4,
              child: RouteMap(points: points, checkpoints: t.checkpoints, follow: true, controller: _map),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StatTile(label: 'Temps', value: formatDuration(t.elapsed), large: true),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      StatTile(
                          label: 'Distance',
                          value: ((m?.distanceM ?? 0) / 1000).toStringAsFixed(2),
                          unit: 'km'),
                      StatTile(label: 'Allure', value: formatPace(m?.currentSpeedMps ?? 0), unit: '/km'),
                      StatTile(
                          label: 'Vitesse moy.',
                          value: ((m?.avgSpeedMps ?? 0) * 3.6).toStringAsFixed(1),
                          unit: 'km/h'),
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      StatTile(label: 'Calories', value: (m?.calories ?? 0).round().toString(), unit: 'kcal'),
                      StatTile(
                          label: 'D+ / D-',
                          value: '${(m?.elevationGainM ?? 0).round()} / ${(m?.elevationLossM ?? 0).round()}',
                          unit: 'm'),
                      StatTile(label: 'Pas', value: t.steps.toString()),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.flag),
                    label: Text('Checkpoint (${t.checkpoints.length})'),
                    onPressed: t.state == TrackerState.running ? t.addCheckpoint : null,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  iconSize: 32,
                  icon: Icon(t.state == TrackerState.paused ? Icons.play_arrow : Icons.pause),
                  onPressed: t.state == TrackerState.idle
                      ? null
                      : (t.state == TrackerState.paused ? t.resume : t.pause),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  iconSize: 32,
                  style: IconButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.stop),
                  onPressed: t.state == TrackerState.idle ? null : () => _finish(t),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
