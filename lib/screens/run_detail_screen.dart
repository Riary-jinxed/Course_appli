import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/run.dart';
import '../services/geo.dart';
import '../services/run_repository.dart';
import '../share/run_share_card.dart';
import '../shoes/shoes.dart';
import '../social/backup_service.dart';
import '../social/social_repository.dart';
import '../theme/app_theme.dart';
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(height: 320, child: RouteMap(points: run.points, checkpoints: run.checkpoints)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatTile(
                            label: 'Distance',
                            value: (run.distanceM / 1000).toStringAsFixed(2),
                            unit: 'km',
                            large: true,
                            align: CrossAxisAlignment.start,
                          ),
                          const Spacer(),
                          StatTile(label: 'Temps', value: formatDuration(run.movingTime), align: CrossAxisAlignment.end),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 72,
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          StatCard(icon: Icons.speed, label: 'Allure moy.', value: formatPace(run.avgSpeedMps), unit: '/km'),
                          StatCard(
                              icon: Icons.bolt,
                              label: 'Vitesse moy. / max',
                              value: '${(run.avgSpeedMps * 3.6).toStringAsFixed(1)} / ${(run.maxSpeedMps * 3.6).toStringAsFixed(1)}',
                              unit: 'km/h',
                              accent: AppColors.volt),
                          StatCard(
                              icon: Icons.local_fire_department,
                              label: 'Calories',
                              value: run.calories.round().toString(),
                              unit: 'kcal',
                              accent: AppColors.danger),
                          StatCard(
                              icon: Icons.terrain,
                              label: 'Dénivelé + / -',
                              value: '${run.elevationGainM.round()} / ${run.elevationLossM.round()}',
                              unit: 'm',
                              accent: AppColors.mint),
                          StatCard(
                              icon: Icons.directions_walk,
                              label: 'Pas',
                              value: run.steps.toString(),
                              accent: AppColors.gold),
                          StatCard(
                              icon: Icons.graphic_eq,
                              label: 'Cadence',
                              value: run.cadence.round().toString(),
                              unit: 'pas/min',
                              accent: AppColors.gold),
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
                    _ShoeTile(runId: run.id!, shoeId: run.shoeId),
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
            leading: const Icon(Icons.flag, color: AppColors.gold),
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

/// Paire de chaussures utilisée pour cette course (modifiable).
class _ShoeTile extends StatefulWidget {
  final int runId;
  final int? shoeId;
  const _ShoeTile({required this.runId, required this.shoeId});

  @override
  State<_ShoeTile> createState() => _ShoeTileState();
}

class _ShoeTileState extends State<_ShoeTile> {
  List<Shoe> _shoes = [];
  late int? _id = widget.shoeId;

  @override
  void initState() {
    super.initState();
    context.read<ShoeRepository>().list().then((s) {
      if (mounted) setState(() => _shoes = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shoes.isEmpty) return const SizedBox.shrink();
    final current = _shoes.where((s) => s.id == _id).firstOrNull;
    return ListTile(
      leading: const Icon(Icons.hiking),
      title: Text(current?.name ?? 'Aucune paire'),
      subtitle: const Text('Chaussures utilisées'),
      trailing: const Icon(Icons.edit),
      onTap: () async {
        final repo = context.read<ShoeRepository>();
        final picked = await showDialog<int>(
          context: context,
          builder: (c) => SimpleDialog(title: const Text('Chaussures'), children: [
            SimpleDialogOption(onPressed: () => Navigator.pop(c, -1), child: const Text('Aucune')),
            for (final s in _shoes.where((s) => !s.retired || s.id == _id))
              SimpleDialogOption(onPressed: () => Navigator.pop(c, s.id), child: Text('${s.name} (${s.km.round()} km)')),
          ]),
        );
        if (picked == null) return;
        final id = picked == -1 ? null : picked;
        await repo.assign(widget.runId, id);
        setState(() => _id = id);
      },
    );
  }
}
