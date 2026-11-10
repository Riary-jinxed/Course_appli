import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'goal_detail_screen.dart';
import 'goal_form_screen.dart';
import 'models.dart';
import 'plan_repository.dart';

/// Onglet Entraînement : liste des objectifs et prochaine séance.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => TrainingScreenState();
}

class TrainingScreenState extends State<TrainingScreen> {
  late Future<List<(RaceGoal, List<PlannedSession>)>> _data;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    final repo = context.read<PlanRepository>();
    setState(() {
      _data = () async {
        final goals = await repo.goals();
        return [for (final g in goals) (g, await repo.sessions(g.id!))];
      }();
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entraînement')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_goal',
        icon: const Icon(Icons.emoji_events),
        label: const Text('Nouvel objectif'),
        onPressed: () => _open(const GoalFormScreen()),
      ),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Ajoute une épreuve (10 km, semi, marathon…) et je te prépare un programme '
                  'adapté à ton niveau et à la date.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [for (final (g, s) in items) _GoalCard(goal: g, sessions: s, onTap: () => _open(GoalDetailScreen(goal: g)))],
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final RaceGoal goal;
  final List<PlannedSession> sessions;
  final VoidCallback onTap;
  const _GoalCard({required this.goal, required this.sessions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final daysLeft = DateTime(goal.date.year, goal.date.month, goal.date.day).difference(todayStart).inDays;
    final past = sessions.where((s) => s.date.isBefore(todayStart) && s.type != SessionType.race);
    final done = past.where((s) => s.done).length;
    final next = sessions.where((s) => !s.done && !s.date.isBefore(todayStart)).firstOrNull;
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(goal.name, style: t.titleLarge)),
                Text(daysLeft > 0 ? 'J-$daysLeft' : (daysLeft == 0 ? "Aujourd'hui !" : 'Terminé'),
                    style: t.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
              ]),
              Text('${goal.distanceKm} km · ${DateFormat.yMMMMd('fr_FR').format(goal.date)}'),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: sessions.isEmpty ? 0 : sessions.where((s) => s.done).length / sessions.length,
              ),
              const SizedBox(height: 4),
              Text('${sessions.where((s) => s.done).length}/${sessions.length} séances faites'
                  '${past.isEmpty ? '' : ' · $done/${past.length} à jour'}',
                  style: t.bodySmall),
              if (next != null) ...[
                const Divider(height: 24),
                Text('Prochaine séance · ${DateFormat('EEEE d MMM', 'fr_FR').format(next.date)}',
                    style: t.labelLarge),
                const SizedBox(height: 4),
                Text(next.description),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
