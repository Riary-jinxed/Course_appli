import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/run.dart';
import '../services/geo.dart';
import '../services/run_repository.dart';
import '../share/run_share_card.dart';
import '../social/backup_service.dart';
import '../social/social_repository.dart';
import '../widgets/route_map.dart';
import '../widgets/stat_tile.dart';

class RunDetailScreen extends StatelessWidget {
  final int runId;
  const RunDetailScreen({super.key, required this.runId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<RunRepository>();
    return FutureBuilder<Run?>(
      future: repo.get(runId),
      builder: (context, snap) {
        final run = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(run == null ? 'Course' : DateFormat('EEEE d MMMM', 'fr_FR').format(run.startedAt)),
            actions: [
              if (run != null && run.points.length >= 2)
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Partager une image',
                  onPressed: () => showShareSheet(context, run),
                ),
              if (run != null && SupabaseConfig.enabled) _ShareButton(run: run),
              if (run != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Supprimer',
                  onPressed: () async {
                    final social = context.read<SocialRepository>();
                    final backup = context.read<BackupService>();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Supprimer cette course ?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      if (social.userId != null) await social.unshareRun(runId).catchError((_) {});
                      await backup.remove(run.startedAt);
                      await repo.delete(runId);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
          body: run == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    SizedBox(height: 260, child: RouteMap(points: run.points, checkpoints: run.checkpoints)),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        alignment: WrapAlignment.spaceAround,
                        runSpacing: 16,
                        spacing: 24,
                        children: [
                          StatTile(label: 'Distance', value: (run.distanceM / 1000).toStringAsFixed(2), unit: 'km'),
                          StatTile(label: 'Temps', value: formatDuration(run.movingTime)),
                          StatTile(label: 'Allure moy.', value: formatPace(run.avgSpeedMps), unit: '/km'),
                          StatTile(label: 'Vitesse moy.', value: (run.avgSpeedMps * 3.6).toStringAsFixed(1), unit: 'km/h'),
                          StatTile(label: 'Vitesse max', value: (run.maxSpeedMps * 3.6).toStringAsFixed(1), unit: 'km/h'),
                          StatTile(label: 'Calories', value: run.calories.round().toString(), unit: 'kcal'),
                          StatTile(label: 'D+', value: run.elevationGainM.round().toString(), unit: 'm'),
                          StatTile(label: 'D-', value: run.elevationLossM.round().toString(), unit: 'm'),
                          StatTile(label: 'Pas', value: run.steps.toString()),
                          StatTile(label: 'Cadence', value: run.cadence.round().toString(), unit: 'pas/min'),
                        ],
                      ),
                    ),
                    if (run.points.length >= 2)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: FilledButton.icon(
                          icon: const Icon(Icons.ios_share),
                          label: const Text('Partager ma course (WhatsApp…)'),
                          onPressed: () => showShareSheet(context, run),
                        ),
                      ),
                    if (run.points.length > 2) _ElevationChart(points: run.points),
                    if (run.checkpoints.isNotEmpty) ..._checkpoints(context, run),
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _checkpoints(BuildContext context, Run run) {
    var prevD = 0.0;
    var prevT = Duration.zero;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Text('Checkpoints', style: Theme.of(context).textTheme.titleMedium),
      ),
      for (final c in run.checkpoints)
        () {
          final d = c.distanceM - prevD;
          final dt = c.elapsed - prevT;
          prevD = c.distanceM;
          prevT = c.elapsed;
          final speed = dt.inSeconds == 0 ? 0.0 : d / dt.inSeconds;
          return ListTile(
            leading: const Icon(Icons.flag, color: Colors.amber),
            title: Text(c.label),
            subtitle: Text('${(c.distanceM / 1000).toStringAsFixed(2)} km à ${formatDuration(c.elapsed)}'),
            trailing: Text('+${(d / 1000).toStringAsFixed(2)} km\n${formatPace(speed)} /km',
                textAlign: TextAlign.right),
          );
        }(),
    ];
  }
}

class _ElevationChart extends StatelessWidget {
  final List<TrackPoint> points;
  const _ElevationChart({required this.points});

  @override
  Widget build(BuildContext context) {
    // Altitude en fonction de la distance cumulée.
    final spots = <FlSpot>[];
    var dist = 0.0;
    for (var i = 0; i < points.length; i++) {
      if (i > 0) {
        dist += haversineM(points[i - 1].lat, points[i - 1].lng, points[i].lat, points[i].lng);
      }
      spots.add(FlSpot(dist / 1000, points[i].altitude));
    }
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text('Profil d\'altitude', style: Theme.of(context).textTheme.titleMedium),
          ),
          SizedBox(
            height: 160,
            child: LineChart(LineChartData(
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(),
                rightTitles: AxisTitles(),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  dotData: const FlDotData(show: false),
                  color: color,
                  belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.2)),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

/// Partage (ou retire) le résumé de la course auprès des amis et des groupes.
class _ShareButton extends StatefulWidget {
  final Run run;
  const _ShareButton({required this.run});

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool? _shared;

  @override
  void initState() {
    super.initState();
    context.read<SocialRepository>().isShared(widget.run.id!).then(
          (v) => mounted ? setState(() => _shared = v) : null,
          onError: (_) => mounted ? setState(() => _shared = false) : null,
        );
  }

  Future<void> _toggle() async {
    final repo = context.read<SocialRepository>();
    final messenger = ScaffoldMessenger.of(context);
    if (repo.userId == null) {
      messenger.showSnackBar(const SnackBar(content: Text("Connecte-toi dans l'onglet Social pour partager.")));
      return;
    }
    try {
      if (_shared == true) {
        await repo.unshareRun(widget.run.id!);
      } else {
        await repo.shareRun(widget.run);
      }
      setState(() => _shared = !(_shared ?? false));
      messenger.showSnackBar(SnackBar(
          content: Text(_shared! ? 'Course partagée avec tes amis et groupes' : 'Partage retiré')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(_shared == true ? Icons.people : Icons.people_outline),
        tooltip: _shared == true ? 'Ne plus partager avec mes amis' : 'Partager avec mes amis et groupes',
        onPressed: _shared == null ? null : _toggle,
      );
}
