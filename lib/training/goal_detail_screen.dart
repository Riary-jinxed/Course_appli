import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/geo.dart';
import 'models.dart';
import 'plan_repository.dart';

class GoalDetailScreen extends StatefulWidget {
  final RaceGoal goal;
  const GoalDetailScreen({super.key, required this.goal});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late Future<List<PlannedSession>> _sessions;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      setState(() => _sessions = context.read<PlanRepository>().sessions(widget.goal.id!));

  IconData _icon(SessionType t) => switch (t) {
        SessionType.easy => Icons.directions_walk,
        SessionType.long => Icons.route,
        SessionType.tempo => Icons.speed,
        SessionType.intervals => Icons.bolt,
        SessionType.race => Icons.emoji_events,
      };

  Future<void> _toggle(PlannedSession s) async {
    await context.read<PlanRepository>().setSessionDone(s.id!, !s.done);
    _reload();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer cet objectif et son programme ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<PlanRepository>().deleteGoal(widget.goal.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    return Scaffold(
      appBar: AppBar(
        title: Text(g.name),
        actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: FutureBuilder<List<PlannedSession>>(
        future: _sessions,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final sessions = snap.data!;
          final today = DateTime.now();
          final todayStart = DateTime(today.year, today.month, today.day);
          // Regroupement par semaine (lundi).
          final weeks = <DateTime, List<PlannedSession>>{};
          for (final s in sessions) {
            final monday = DateTime(s.date.year, s.date.month, s.date.day - (s.date.weekday - 1));
            weeks.putIfAbsent(monday, () => []).add(s);
          }
          final entries = weeks.entries.toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${g.distanceKm} km le ${DateFormat.yMMMMd('fr_FR').format(g.date)}'
                  '${g.targetTime == null ? '' : ' · objectif ${formatDuration(g.targetTime!)}'}\n'
                  'Coche une séance pour la valider. Une course enregistrée le jour prévu la valide automatiquement.',
                ),
              ),
              for (final (i, e) in entries.indexed) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Semaine ${i + 1} · ${e.value.fold<double>(0, (s, x) => s + x.distanceKm).toStringAsFixed(1)} km'
                    '${entries.length - i == 2 ? ' · affûtage' : ''}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final s in e.value)
                  CheckboxListTile(
                    value: s.done,
                    onChanged: s.type == SessionType.race && s.date.isAfter(todayStart) ? null : (_) => _toggle(s),
                    secondary: Icon(_icon(s.type),
                        color: s.date.isBefore(todayStart) && !s.done ? Colors.grey : null),
                    title: Text('${DateFormat('EEE d MMM', 'fr_FR').format(s.date)} · ${s.type.label}'),
                    subtitle: Text(s.description),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
